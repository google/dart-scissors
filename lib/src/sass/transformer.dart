// Copyright 2015 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
library scissors.src.sass.transformer;

import 'dart:async';
import 'dart:io';

import 'package:barback/barback.dart';
import 'package:path/path.dart';
import 'package:quiver/check.dart';

import 'sassc_runner.dart' show SasscSettings, runSassC;
import '../image_inlining/image_inliner.dart';
export '../image_inlining/image_inliner.dart' show ImageInliningMode;
import '../utils/deps_consumer.dart';
import '../utils/enum_parser.dart';
import '../utils/file_skipping.dart';
import '../utils/path_resolver.dart';
import '../utils/result.dart' show TransformResult;
import '../utils/settings_base.dart';
import '../utils/transformer_utils.dart' show getInputs, getDeclaredInputs;

part 'settings.dart';

final RegExp _classifierRx =
    new RegExp(r'^(.*?\.s[ac]ss)(?:\.css(?:\.map)?)?$');

typedef String _PackageRewriter(String s);

class SassCTransformer extends AggregateTransformer
    implements DeclaringAggregateTransformer {
  final SassSettings _settings;
  _PackageRewriter _rewritePackage;

  SassCTransformer(this._settings) {
    _rewritePackage = _getPackageRewriter(_settings.packageRewrites.value);
  }

  SassCTransformer.asPlugin(BarbackSettings settings)
      : this(new _SassSettings(settings));

  @override
  classifyPrimary(AssetId id) {
    if (!_settings.compileSass.value || shouldSkipAsset(id)) return null;

    final prefix = _classifierRx.matchAsPrefix(id.path)?.group(1);
    return prefix == null ? null : '${id.package}|$prefix';
  }

  @override
  declareOutputs(DeclaringAggregateTransform transform) async {
    final inputs = await getDeclaredInputs(transform);
    final AssetId scss = inputs['.scss'] ?? inputs['.sass'];
    if (scss == null) return;

    // Don't consume the sass file in debug, for maps to work.
    if (!_settings.isDebug) transform.consumePrimary(scss);
    var cssId = (await _settings.sasscSettings).getCssOutputId(scss);
    transform.declareOutput(cssId);
    transform.declareOutput(cssId.addExtension('.map'));
  }

  Future apply(AggregateTransform transform) async {
    final inputs = await getInputs(transform);
    final Asset scss = inputs['.scss'] ?? inputs['.sass'];
    final Asset css = inputs['.css'];
    if (scss == null) return;

    var sasscSettings = await _settings.sasscSettings;

    // Mark transitive SASS @imports as barback dependencies.
    Future<Set<AssetId>> depsFuture = consumeTransitiveSassDeps(
        transform.getInput,
        transform.logger,
        scss,
        sasscSettings.sasscIncludes);

    if (css != null && _settings.onlyCompileOutOfDateSass.value) {
      Future<DateTime> cssTimeFuture = _getLastModified(css.id);
      List<DateTime> depsTimes =
          (await Future.wait((await depsFuture).map(_getLastModified)));

      var cssTime = await cssTimeFuture;
      var moreRecentInputs = depsTimes.where((t) => t.compareTo(cssTime) > 0);
      if (moreRecentInputs.isEmpty) {
        // Don't do anything: css is more recent than its inputs!
        transform.logger.info(
            'File is more recent than its ${depsTimes.length} inputs, skipping',
            asset: css.id);
        return;
      } else {
        transform.logger.info(
            'File is older than ${moreRecentInputs.length}/${depsTimes.length} of its inputs: recompiling',
            asset: css.id);
      }
    }

    var cssResult = await runSassC(scss,
        isDebug: _settings.isDebug, settings: sasscSettings);
    cssResult.logMessages(transform.logger);
    if (!cssResult.success) return;

    // Don't consume the sass file in debug, for maps to work.
    if (!_settings.isDebug) transform.consumePrimary(scss.id);

    TransformResult result;

    var inliningResult =
        await inlineImages(cssResult.css, _settings.imageInlining.value,
            assetFetcher: (String url, {AssetId from}) {
      return pathResolver.resolveAsset(transform.getInput, [url], from);
    }, resolveLinkToAsset: (Asset asset) {
      var uri = pathResolver.assetIdToUri(asset.id);
      return _rewritePackage(uri);
    });

    if (inliningResult.success && inliningResult.css == null) {
      // inlineImage fast-failed.
      result = cssResult;
    } else {
      inliningResult.logMessages(transform.logger);
      if (!inliningResult.success) return;

      result = inliningResult;
    }

    transform.addOutput(result.css);
    // In theory we should compose cssResult.map with inliningResult.map.
    // In practice it doesn't matter as image inlining preserves lines.
    if (cssResult.map != null) transform.addOutput(cssResult.map);
  }
}

Future<DateTime> _getLastModified(id) async =>
    (await pathResolver.resolveAssetFile(id is Future ? await id : id))
        ?.lastModified();

_PackageRewriter _getPackageRewriter(String fromToString) {
  var fromTo = fromToString.split(',');
  checkState(fromTo.length == 2,
      message: () => "Expected from,to pattern, got: $fromToString");
  var fromRx = new RegExp(fromTo[0]);
  var to = fromTo[1];
  return (String s) => s.replaceFirst(fromRx, to);
}

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
library scissors.src.image_inlining.transformer;

import 'dart:async';

import 'package:barback/barback.dart';
import 'package:quiver/check.dart';

import '../image_inlining/image_inliner.dart';
export '../image_inlining/image_inliner.dart' show ImageInliningMode;
import '../utils/path_resolver.dart';
import '../utils/settings_base.dart';
import '../utils/enum_parser.dart';
import '../utils/file_skipping.dart';
import '../utils/transformer_utils.dart' show getInputs, getDeclaredInputs;

part 'settings.dart';

typedef String _PackageRewriter(String s);

final RegExp _classifierRx = new RegExp(r'^(.*?\.css)(?:\.map)?$');

class ImageInliningTransformer extends AggregateTransformer
    implements DeclaringAggregateTransformer {
  final ImageInliningSettings _settings;
  _PackageRewriter _rewritePackage;

  ImageInliningTransformer(this._settings) {
    _rewritePackage = _getPackageRewriter(_settings.packageRewrites.value);
  }

  ImageInliningTransformer.asPlugin(BarbackSettings settings)
      : this(new _ImageInliningSettings(settings));

  @override
  classifyPrimary(AssetId id) {
    if (_settings.imageInlining.value == ImageInliningMode.disablePass ||
        shouldSkipAsset(id)) {
      return null;
    }
    return '${id.package}|${_classifierRx.matchAsPrefix(id.path)?.group(1)}';
  }

  @override
  declareOutputs(DeclaringAggregateTransform transform) async {
    final inputs = await getDeclaredInputs(transform);
    final AssetId css = inputs['.css'];
    if (css == null) return;

    transform.declareOutput(css);
    transform.declareOutput(css.addExtension('.map'));
  }

  Future apply(AggregateTransform transform) async {
    final inputs = await getInputs(transform);
    final Asset css = inputs['.css'];
    final Asset map = inputs['.map'];
    if (css == null) return;

    var result = await inlineImages(css, _settings.imageInlining.value,
        assetFetcher: (String url, {AssetId from}) {
      return pathResolver.resolveAsset(transform.getInput, [url], from);
    }, resolveLinkToAsset: (Asset asset) {
      var uri = pathResolver.assetIdToUri(asset.id);
      return _rewritePackage(uri);
    });
    result.logMessages(transform.logger);
    if (!result.success) return;

    if (result.css == null) {
      transform.addOutput(css);
      if (map != null) transform.addOutput(map);
      return;
    }
    transform.addOutput(result.css);
    if (result.map != null) transform.addOutput(result.map);
  }
}

_PackageRewriter _getPackageRewriter(String fromToString) {
  var fromTo = fromToString.split(',');
  checkState(fromTo.length == 2,
      message: () => "Expected from,to pattern, got: $fromToString");
  var fromRx = new RegExp(fromTo[0]);
  var to = fromTo[1];
  return (String s) => s.replaceFirst(fromRx, to);
}

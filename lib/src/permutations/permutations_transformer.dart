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
library scissors.src.permutations.transformer;

import 'dart:async';
import 'dart:io';

import 'package:barback/barback.dart';
import 'package:path/path.dart';

import '../path_resolver.dart';
import '../settings.dart';
import '../closure.dart';
import 'intl_deferred_map.dart';

/// This transformer stitches deferred message parts together in pre-assembled
/// .js artefact permutations, to speed up initial loading of pages.
///
/// It must be run *after* the $dart2js transformer, and $dart2js must have the
/// a `--deferred-map=something` parameter
/// (see `example/permutations/pubspec.yaml`).
///
/// For instance if `main.dart.js` defer-loads messages for locales `en` and
/// `fr`, this transformer will create the artefact `main_en.js` (still able
/// to defer-load the `fr` locale, but with instant loading of locale `en`) and
/// `main_fr.js` (the opposite).
///
/// This lives in sCiSSors so that additional optimizations can be performed on
/// the stitched output, for instance running Closure Compiler in SIMPLE mode
/// on the resulting stitched output saves 10% of raw size in
/// example/permutations/build/web/main_en.js (85kB -> 76kB), and still
/// 1kB / 24kB in gzipped size.
///
/// cat example/permutations/build/web/main_en.js | gzip -9 | wc -c
/// cat example/permutations/build/web/main_en.js | java -jar compiler.jar --language_in=ES5 --language_out=ES5 -O SIMPLE | gzip -9 | wc -c
///
/// This might interact with the CSS mirroring feature, in ways still TBD.
///
class PermutationsTransformer extends AggregateTransformer {
  final ScissorsSettings _settings;

  PermutationsTransformer(this._settings);

  PermutationsTransformer.asPlugin(BarbackSettings settings)
      : this(new ScissorsSettings.fromSettings(settings));

  static final _allowedExtensions =
      ".dart.js .part.js .deferred_map".split(' ').toList();

  @override
  classifyPrimary(AssetId id) =>
      _allowedExtensions.any((x) => id.path.endsWith(x)) ? '<default>' : null;

  @override
  apply(AggregateTransform transform) async {
    var inputs = await transform.primaryInputs.toList();
    if (inputs.isEmpty) return;

    var inputIds = inputs.map((i) => i.id).toList();
    var deferredMapAsset = inputs.firstWhere(
        (a) => a.id.extension == '.deferred_map',
        orElse: () => throw new ArgumentError(
            r'Option --deferred-map was not set on $dart2js transformer, '
            'or permutations transformer was executed before it.'));

    var deferredMapJson = await deferredMapAsset.readAsString();
    if (_settings.verbose.value) {
      transform.logger.info('Deferred map content:\n$deferredMapJson');
    }
    var map = new IntlDeferredMap.fromJson(deferredMapJson);

    if (_settings.verbose.value) {
      transform.logger.info('Found entry points ${map.mainNames}, '
          'and locales ${map.locales}');
    }

    Asset getMatchingAsset(String fileName) =>
        inputs.firstWhere((a) => a.id.path.endsWith(fileName),
            orElse: () => throw new ArgumentError('No $fileName in $inputIds'));

    var futures = <Future>[];
    for (var mainName in map.mainNames) {
      // TODO(ochafik): check rest of path matches!
      Asset mainAsset = getMatchingAsset('$mainName.dart.js');
      transform.logger.info('Processing ${mainAsset.id}');

      for (var locale in map.locales) {
        var permutationId = new AssetId(mainAsset.id.package,
            join(dirname(mainAsset.id.path), '${mainName}_${locale}.js'));

        var parts = map.getPartsForLocale(
            locale: locale,
            rtlImportAlias: _settings.rtlImport.value,
            ltrImportAlias: _settings.ltrImport.value);

        var importAliasesByAssets = <Asset, List<String>>{};
        importAliasesByAssets[mainAsset] = <String>[];
        for (var part in parts) {
          importAliasesByAssets[getMatchingAsset(part)] =
              map.getImportAliasesForPart(part);
        }
        List<Asset> assets = importAliasesByAssets.keys.toList();

        describeAsset(Asset asset) {
          var importedBy = importAliasesByAssets[asset];
          var name = "${asset.id}";
          return importedBy.isEmpty
              ? name
              : '$name (used by: ${importedBy.join(", ")})';
        }
        transform.logger.info('Creating $permutationId with:\n'
            '\t${assets.map(describeAsset).join("\n\t")}');

        futures.add(_concatenateAssets(transform, permutationId, assets));
      }
    }
    await Future.wait(futures);
  }

  Future _concatenateAssets(AggregateTransform transform, AssetId permutationId,
      List<Asset> assets) async {
    var futureStrings = assets.map((a) => a.readAsString());
    var content = (await Future.wait(futureStrings)).join('\n');

    if (_settings.reoptimizePermutations.value) {
      try {
        var path = await pathResolver
            .resolvePath(_settings.closureCompilerJarPath.value);
        if (await new File(path).exists()) {
          var result = await simpleClosureCompile(path, content);
          transform.logger.info('Ran Closure Compiler on $permutationId: '
              'before = ${content.length}, after = ${result.length}');

          transform.addOutput(new Asset.fromString(
              permutationId.addExtension('.before_closure.js'), content));
          content = result;
        } else {
          transform.logger.warning("Did not find Closure Compiler ($path): "
              "permutations won't be fully optimized.");
        }
      } catch (e, s) {
        print('$e\n$s');
      }
    }
    transform.addOutput(new Asset.fromString(permutationId, content));
  }
}

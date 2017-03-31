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

import 'package:barback/barback.dart';
import 'package:intl/number_symbols_data.dart';
import 'package:path/path.dart';

import 'intl_deferred_map.dart';
import '../js_optimization/js_optimization.dart';
import '../js_optimization/settings.dart';
import '../sourcemap_stripping/sourcemap_stripping.dart';
import '../utils/settings_base.dart';

part 'settings.dart';

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
/// cat example/permutations/build/web/main_en.js | java -jar compiler.jar --language_out=ES5 -O SIMPLE | gzip -9 | wc -c
///
/// This might interact with the CSS mirroring feature, in ways still TBD.
///
class PermutationsTransformer extends AggregateTransformer
    implements LazyAggregateTransformer {
  final PermutationsSettings _settings;

  PermutationsTransformer(this._settings);
  PermutationsTransformer.asPlugin(BarbackSettings settings)
      : this(new _PermutationsSettings(settings));

  static final _allowedExtensions = [
    '.dart.js',
    '.dart.js.map',
    '.part.js',
    '.part.js.map',
    '.deferred_map'
  ];

  @override
  classifyPrimary(AssetId id) => _settings.generatePermutations.value &&
          _allowedExtensions.any((x) => id.path.endsWith(x))
      ? '<default>'
      : null;

  @override
  declareOutputs(DeclaringAggregateTransform transform) async {
    var dartJsId = (await transform.primaryIds.toList())
        .firstWhere((a) => a.path.endsWith('.dart.js'), orElse: () => null);
    if (dartJsId != null) {
      for (var locale in _settings.potentialLocales.value) {
        var permutationId = new AssetId(dartJsId.package,
            dartJsId.path.replaceAll('.dart.js', '_$locale.js'));
        transform.declareOutput(permutationId);
        transform.declareOutput(permutationId.addExtension('.map'));
      }
    }
  }

  @override
  apply(AggregateTransform transform) async {
    var inputs = await transform.primaryInputs.toList();
    if (inputs.isEmpty) return;

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

    var defaultLocale = _settings.defaultLocale.value;
    var allLocales = <String>[]..addAll(map.locales);
    if (defaultLocale != null) allLocales.add(defaultLocale);

    if (_settings.verbose.value) {
      transform.logger.info('Found entry points ${map.mainNames}, '
          'and locales ${map.locales} with default locale $defaultLocale');
    }

    Asset getMatchingAsset(String path, {bool throwIfNotFound: true}) =>
        inputs.firstWhere((a) => a.id.path.endsWith(path), orElse: () {
          if (!throwIfNotFound) return null;

          var ids = inputs.map((a) => a.id);
          throw new ArgumentError('$path not found in $ids');
        });

    var futureAssetStrings = <Asset, Future<String>>{};
    var futures = <Future>[];
    for (var mainName in map.mainNames) {
      // TODO(ochafik): check rest of path matches!
      var mainJsName = '$mainName.dart.js';
      Asset mainAsset = getMatchingAsset(mainJsName);
      Asset sourcemapAsset =
          getMatchingAsset('$mainJsName.map', throwIfNotFound: false);
      transform.logger.info('Processing ${mainAsset.id}');

      for (var locale in allLocales) {
        var permutationId = new AssetId(mainAsset.id.package,
            join(dirname(mainAsset.id.path), '${mainName}_$locale.js'));

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
        for (var asset in assets) {
          futureAssetStrings.putIfAbsent(
              asset, () async => stripSourcemap(await asset.readAsString()));
        }

        if (_settings.verbose.value) {
          describeAsset(Asset asset) {
            var importedBy = importAliasesByAssets[asset];
            var name = "${asset.id}";
            return importedBy.isEmpty
                ? name
                : '$name (used by: ${importedBy.join(", ")})';
          }

          transform.logger.info('Creating $permutationId with:\n'
              '\t${assets.map(describeAsset).join("\n\t")}');
        } else {
          transform.logger
              .info('Creating $permutationId with ${assets.length} assets');
        }

        futures.add(_concatenateAssets(transform, permutationId, assets,
            futureAssetStrings, sourcemapAsset));
      }
    }
    await Future.wait(futures);
  }

  Future _concatenateAssets(
      AggregateTransform transform,
      AssetId permutationId,
      List<Asset> assets,
      Map<Asset, Future<String>> futureAssetStrings,
      Asset sourcemapAsset) async {
    var futureStrings = assets.map((a) => futureAssetStrings[a]);
    var content = (await Future.wait(futureStrings)).join('\n');

    if (sourcemapAsset != null) {
      var sourcemapId = permutationId.addExtension('.map');
      transform
          .addOutput(new Asset.fromStream(sourcemapId, sourcemapAsset.read()));
      content += '\n//# sourceMappingURL=${basename(sourcemapId.path)}';
    }

    var contentAsset = new Asset.fromString(permutationId, content);
    if (_settings.reoptimizePermutations.value) {
      try {
        contentAsset =
            await optimizeJsAsset(transform.logger, contentAsset, _settings);
        transform.addOutput(new Asset.fromString(
            permutationId.addExtension('.before_closure.js'), content));
      } catch (e, s) {
        transform.logger.warning(
            "Unexpected error while running the Closure Compiler: permutations won't be fully optimized.\n$e\n$s");
      }
    }
    transform.addOutput(contentAsset);
  }
}

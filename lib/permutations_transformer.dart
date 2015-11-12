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
library scissors.permutations_transformer;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:barback/barback.dart';
import 'package:quiver/check.dart';
import 'package:path/path.dart';

import 'src/path_resolver.dart';
import 'src/settings.dart';
import 'src/closure.dart';

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

    var data = JSON.decode(await deferredMapAsset.readAsString());

    var futures = <Future>[];
    data.forEach((key, value) {
      // TODO(ochafik): Strengthen matching.
      if (key.endsWith("messages_all.dart")) {
        var imports = value['imports'];
        checkNotNull(imports, message: () => "No imports in $value");
        imports.forEach((alias, parts) {
          checkState(alias.startsWith("messages_"));
          var locale = alias.substring("messages_".length);

          var partsByMainName = <String, List<String>>{};
          for (var part in parts) {
            Match m = checkNotNull(_partRx.firstMatch(part),
                message: () => '$part does not look like a part path');
            var mainName = m[1];

            partsByMainName.putIfAbsent(mainName, () => <String>[]).add(part);
          }

          Asset getMatchingAsset(String fileName) =>
              inputs.firstWhere((a) => a.id.path.endsWith(fileName),
                  orElse: () =>
                      throw new ArgumentError('No $fileName in $inputIds'));

          partsByMainName.forEach((mainName, parts) {
            // TODO(ochafik): check rest of path matches!
            Asset mainAsset = getMatchingAsset('$mainName.dart.js');
            List<Asset> assets = [mainAsset]
              ..addAll(parts.map((part) => getMatchingAsset(part)));

            var permutationId = new AssetId(mainAsset.id.package,
                join(dirname(mainAsset.id.path), '${mainName}_${locale}.js'));

            transform.logger.info('Creating $permutationId with:\n'
                '\t${assets.map((a) => a.id).join("\n\t")}');

            futures.add((() async {
              var futureStrings = assets.map((a) => a.readAsString());
              var content = (await Future.wait(futureStrings)).join('\n');

              if (_settings.reoptimizePermutations.value) {
                try {
                  var path = await pathResolver
                      .resolvePath(_settings.closureCompilerJarPath.value);
                  if (await new File(path).exists()) {
                    var result = await simpleClosureCompile(path, content);
                    transform.logger.info(
                        'Ran Closure Compiler on $permutationId: '
                        'before = ${content.length}, after = ${result.length}');

                    transform.addOutput(new Asset.fromString(
                        permutationId.addExtension('.before_closure.js'),
                        content));
                    content = result;
                  } else {
                    transform.logger
                        .warning("Did not find Closure Compiler ($path): "
                            "permutations won't be fully optimized.");
                  }
                } catch (e, s) {
                  print('$e\n$s');
                }
              }
              transform.addOutput(new Asset.fromString(permutationId, content));
            })());
          });
        });
      }
    });
    await Future.wait(futures);
  }

  static final RegExp _partRx = new RegExp(r'^(.*?)\.dart\.js_\d+\.part\.js$');
}

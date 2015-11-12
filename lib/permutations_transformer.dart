library scissors.permutations_transformer;
import 'package:barback/barback.dart';
import 'dart:convert';
import 'package:quiver/check.dart';
import 'package:path/path.dart';
import 'dart:async';

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
/// example/permutations/build/web/main_en.js (85kB -> 76kB), and still 1kB / 24kB in gzipped size.
///
/// cat example/permutations/build/web/main_en.js | gzip -9 | wc -c
/// cat example/permutations/build/web/main_en.js | java -jar compiler.jar --language_in=ES5 --language_out=ES5 -O SIMPLE | gzip -9 | wc -c
///
/// This might interact with the CSS mirroring feature, in ways still TBD.
///
class PermutationsTransformer extends AggregateTransformer {

  PermutationsTransformer.asPlugin(BarbackSettings settings);

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

            partsByMainName.putIfAbsent(mainName, () => <String>[])
                .add(part);
          }

          Asset getMatchingAsset(String fileName) =>
            inputs.firstWhere(
                (a) => a.id.path.endsWith(fileName),
                orElse: () => throw new ArgumentError('No $fileName in $inputIds'));

          partsByMainName.forEach((mainName, parts) {
            // TODO(ochafik): check rest of path matches!
            Asset mainAsset = getMatchingAsset('$mainName.dart.js');
            List<Asset> assets =
                [mainAsset]..addAll(parts.map((part) => getMatchingAsset(part)));

            var permutationId = new AssetId(
                mainAsset.id.package,
                join(dirname(mainAsset.id.path), '${mainName}_${locale}.js'));

            transform.logger.info(
                'Creating $permutationId with:\n'
                '\t${assets.map((a) => a.id).join("\n\t")}');

            futures.add((() async {
              var futureStrings = assets.map((a) => a.readAsString());
              var content = (await Future.wait(futureStrings)).join('\n');
              // TODO(ochafik): Reoptimize the content with Closure Compiler:
              // on example/permutations, can win 10% raw size (4% gzipped) with
              // `--language_in=ES5 --language_out=ES5 -O SIMPLE`
              transform.addOutput(
                  new Asset.fromString(
                      permutationId,
                      content));
            })());
          });
        });
      }
    });
    await Future.wait(futures);
  }

  static final RegExp _partRx = new RegExp(r'^(.*?)\.dart\.js_\d+\.part\.js$');
}

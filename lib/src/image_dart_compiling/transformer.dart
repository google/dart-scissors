import 'package:barback/barback.dart';
import 'package:path/path.dart' show url;
import 'dart:async';
import 'package:scissors/src/utils/io_utils.dart' show readAll;
import 'package:scissors/src/image_dart_compiling/image_dart_compiling.dart';
import '../image_inlining/image_inliner.dart';

const _outputFileName = 'images.dart';

/// Transformer that compiles several image files to a Dart source file with
/// constant definitions that has these image files Base64-encoded.
///
/// Files are grouped by the directory they reside in, and the resulting source
/// would be written to that directory.
class DartImageCompiler extends AggregateTransformer
    implements DeclaringAggregateTransformer {
  DartImageCompiler.asPlugin();

  @override
  apply(AggregateTransform transform) async {
    final list = await transform.primaryInputs.toList();
    list.sort((x, y) => x.id.compareTo(y.id));

    String source = await generateDartSource(await Future.wait(list.map(
        (asset) async =>
            new ImageInformation(asset.id.path, await readAll(asset.read())))));

    final first = list.first.id;
    final dir = url.dirname(first.path);
    final outputPath = url.join(dir, _outputFileName);

    final asset =
        new Asset.fromString(new AssetId(first.package, outputPath), source);

    transform.addOutput(asset);
  }

  @override
  classifyPrimary(AssetId id) {
    if (!imageMediaTypeByExtension.containsKey(url.extension(id.path))) {
      return null;
    }

    return '${id.package}|${url.dirname(id.path)}';
  }

  @override
  Future declareOutputs(DeclaringAggregateTransform transform) async {
    var firstInput = await transform.primaryIds.first;
    var dirname = url.dirname(firstInput.path);
    transform.declareOutput(
        new AssetId(firstInput.package, url.join(dirname, _outputFileName)));
  }
}

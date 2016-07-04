import 'package:barback/barback.dart';
import 'package:path/path.dart';
import 'dart:async';
import 'package:scissors/src/utils/io_utils.dart';
import 'src/image_inlining/image_dart_compiling.dart';
import 'src/image_inlining/image_inliner.dart';

const outputFileName = 'images.dart';

/// Transformer that compiles several image files to a Dart source file with
/// constant definitions that has these image files Base64-encoded.
class DartImageCompiler extends AggregateTransformer
    implements DeclaringAggregateTransformer {
  @override
  apply(AggregateTransform transform) async {
    List<Asset> list = await transform.primaryInputs.toList();
    list.sort((x, y) => x.id.compareTo(y.id));
    String source = await generateDartSource(await Future.wait(list.map(fromAsset)));

    final first = list.first.id;
    final dir = url.dirname(first.path);
    final outputPath = url.join(dir, outputFileName);

    final asset = new Asset.fromString(
        new AssetId(first.package, outputPath), source);

    transform.addOutput(asset);
  }

  @override
  classifyPrimary(AssetId id) {
    if (!mediaTypeByExtension.containsKey(url.extension(id.path))) {
      return null;
    }

    return url.dirname(id.path);
  }

  DartImageCompiler.asPlugin();

  @override
  declareOutputs(DeclaringAggregateTransform transform) async {
    var firstInput = await transform.primaryIds.first;
    var dirname = url.dirname(firstInput.path);
    return url.join(dirname, outputFileName);
  }
}

Future<ImageInformation> fromAsset(Asset asset) async {
  return new ImageInformation(asset.id.path, await readAll(asset.read()));
}


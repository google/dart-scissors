import 'package:barback/barback.dart';
import 'package:path/path.dart';
import 'src/image_inlining/image_inliner.dart';

const svg_extension = ".svg";

/// Transformer that compiles several image files to a Dart source file with
/// constant definitions that has these image files Base64-encoded.
class DartImageCompiler extends AggregateTransformer {
  @override
  apply(AggregateTransform transform) async {
    List<Asset> list = await transform.primaryInputs.toList();
    list.sort((x, y) => x.id.compareTo(y.id));

    final buffer = new StringBuffer();
    for (final asset in list) {
      final data = await encodeDataAsUri(asset);
      final filename = url.basename(asset.id.path);

      // Convert filenames to valid Dart identifiers
      final name = filename
          .substring(0, filename.length - svg_extension.length)
          .replaceAll("-", "_");
      buffer.write('const $name = "$data";\n');
    }

    final first = list.first.id;
    final dir = url.dirname(first.path);
    final outputPath = url.join(dir, "images.dart");

    final asset = new Asset.fromString(
        new AssetId(first.package, outputPath), buffer.toString());

    transform.addOutput(asset);
  }

  @override
  classifyPrimary(AssetId id) {
    if (!id.path.endsWith(svg_extension)) {
      return null;
    }

    return url.dirname(id.path);
  }

  DartImageCompiler.asPlugin();
}

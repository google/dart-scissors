import 'package:barback/barback.dart';
import 'package:path/path.dart';
import 'src/image_inlining/image_inliner.dart';
import 'dart:io';

const outputFileName = 'images.dart';

/// Convert file name to a string suitable for being used as Dart identifier.
/// Currently result isn't guaranteed to be always valid identifier, but
/// function should work for majority of the cases.
String identifierFromFileName(String fileName) {
  return url.basenameWithoutExtension(fileName).replaceAll('-', '_');
}

/// Transformer that compiles several image files to a Dart source file with
/// constant definitions that has these image files Base64-encoded.
class DartImageCompiler extends AggregateTransformer
    implements DeclaringAggregateTransformer {
  @override
  apply(AggregateTransform transform) async {
    List<Asset> list = await transform.primaryInputs.toList();
    list.sort((x, y) => x.id.compareTo(y.id));

    final buffer = new StringBuffer();
    for (final asset in list) {
      final data = await encodeAssetAsUri(asset);
      final name = identifierFromFileName(asset.id.path);
      buffer.write('const ${name} = "$data";\n');
    }

    final first = list.first.id;
    final dir = url.dirname(first.path);
    final outputPath = url.join(dir, outputFileName);

    final asset = new Asset.fromString(
        new AssetId(first.package, outputPath), buffer.toString());

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

/// Command-line entry point. Takes list of paths to pictures, producing Dart
/// source on stdout.
main(List<String> arguments) async {
  void fail(String message) {
    stderr.writeln(message);
    exit(1);
  }

  StringBuffer buffer = new StringBuffer();
  for (final arg in arguments) {
    final dot = arg.lastIndexOf('.');
    if (dot == -1) {
      fail('Cannot determine extension of $arg');
    }

    final extension = arg.substring(dot);
    if (!mediaTypeByExtension.containsKey(extension)) {
      fail('Unknown media type of $arg');
    }

    final data = await encodeMediaAsUri(
        mediaTypeByExtension[extension], await new File(arg).readAsBytes());
    final name = identifierFromFileName(arg);
    buffer.write('const $name = "$data";\n');
  }

  stdout.write(buffer.toString());
}

import 'dart:async';
import 'image_inliner.dart';
import 'package:path/path.dart';

/// Data holder for image-related information: its file name and contents.
class ImageInformation {
  final String fileName;
  final List<int> contents;

  ImageInformation(this.fileName, this.contents);
}

/// Convert file name to a string suitable for being used as Dart identifier.
/// Currently result isn't guaranteed to be always valid identifier, but
/// function should work for majority of the cases.
String identifierFromFileName(String fileName) {
  return url.basenameWithoutExtension(fileName).replaceAll('-', '_');
}

class ConversionException implements Exception {
  final String message;
  ConversionException(this.message);
}

Future<String> generateDartSource(Iterable<ImageInformation> images) async {
  StringBuffer result = new StringBuffer();
  for (final image in images) {
    final extension = url.extension(image.fileName);
    if (!mediaTypeByExtension.containsKey(extension)) {
      throw new ConversionException('unknown image extension "$extension"');
    }

    final name = identifierFromFileName(image.fileName);
    final data =
        await encodeMediaAsUri(mediaTypeByExtension[extension], image.contents);
    result.write('const $name = "$data";\n');
  }
  return result.toString();
}

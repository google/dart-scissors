import 'dart:async';
import '../image_inlining/image_inliner.dart';
import 'package:path/path.dart' as path;

final _illegalCharacters = new RegExp(r'[^\w]+');
final _illegalFirstCharacter = new RegExp(r'\d|_');

/// Data holder for image-related information: its file name and contents.
class ImageInformation {
  final String fileName;
  final List<int> bytes;

  ImageInformation(this.fileName, this.bytes);
}

/// Convert file name to a string suitable for being used as Dart identifier.
/// Currently result isn't guaranteed to be always valid identifier, but
/// function should work for majority of the cases.
String identifierFromFileName(String fileName) {
  final candidate = path
      .basenameWithoutExtension(fileName)
      .replaceAll(_illegalCharacters, '_');

  // Prepend a prefix if starts from an invalid character.
  if (candidate.startsWith(_illegalFirstCharacter)) {
    return "img_" + candidate;
  } else {
    return candidate;
  }
}

class ConversionException implements Exception {
  final String message;
  ConversionException(this.message);
}

Future<String> generateDartSource(Iterable<ImageInformation> images) async {
  StringBuffer result = new StringBuffer();
  for (final image in images) {
    final extension = path.extension(image.fileName);
    if (!imageMediaTypeByExtension.containsKey(extension)) {
      throw new ConversionException(
          'unknown image extension of "${image.fileName}"');
    }

    final name = identifierFromFileName(image.fileName);
    final data = encodeBytesAsDataUri(image.bytes,
        mimeType: imageMediaTypeByExtension[extension]);
    result.write('const $name = "$data";\n');
  }
  return result.toString();
}

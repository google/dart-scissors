import 'dart:async';
import 'dart:io';
import 'package:scissors/src/image_inlining/image_dart_compiling.dart';

Future<ImageInformation> fromFile(String fileName) async {
  return new ImageInformation(fileName, await new File(fileName).readAsBytes());
}

/// Command-line entry point. Takes list of paths to pictures, producing Dart
/// source on stdout.
main(List<String> arguments) async {
  try {
    String source =
        await generateDartSource(await Future.wait(arguments.map(fromFile)));
    stdout.write(source);
  } on ConversionException catch (e) {
    stderr.write("An error occurred while converting images to Dart.\n");
    stderr.write("Error message: ${e.message}");
  }
}

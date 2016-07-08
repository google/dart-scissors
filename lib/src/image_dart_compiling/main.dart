import 'dart:async';
import 'dart:io';
import 'package:scissors/src/image_dart_compiling/image_dart_compiling.dart';

/// Command-line entry point. Takes list of paths to pictures, producing Dart
/// source on stdout.
main(List<String> arguments) async {
  stdout.write(await generateDartSource(await Future.wait(arguments.map(
      (String fileName) async => new ImageInformation(
          fileName, await new File(fileName).readAsBytes())))));
}

import 'dart:io';

import 'package:args/args.dart';
import 'package:scissors/src/css_mirroring/bidi_css_generator.dart';
import 'package:scissors/src/css_mirroring/cssjanus_runner.dart';
import 'package:scissors/src/utils/global_path_resolver.dart';

main(List<String> args) async {
  final argParser = new ArgParser(allowTrailingOptions: true)
    ..addOption('cssjanus-path', defaultsTo: pathResolver.defaultCssJanusPath);

  final parsedArgs = argParser.parse(args);

  File inputFile;
  File outputFile;
  switch (parsedArgs.rest.length) {
    case 1:
      inputFile = new File(parsedArgs.rest[0]);
      break;

    case 2:
      inputFile = new File(parsedArgs.rest[0]);
      outputFile = new File(parsedArgs.rest[1]);
      break;

    default:
      throw new ArgumentError(
          'Expecting one or two arguments (input file name and optional output '
          'file name), got ${parsedArgs.rest.length}');
  }

  final input = await inputFile.readAsString();
  final output = await bidirectionalizeCss(input,
      (String css) async => runCssJanus(css, parsedArgs['cssjanus-path']));

  if (outputFile != null) {
    await outputFile.writeAsString(output);
  } else {
    print(output);
  }
}

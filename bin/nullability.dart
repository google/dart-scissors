#!/usr/bin/env dart
/*
npm i
$(npm bin)/watch "dart --observe bin/nullability.dart" bin lib/src/nullability/ --wait=0
*/
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/source/source_resource.dart';
import 'package:analyzer/src/string_source.dart';
import 'package:front_end/src/base/source.dart';
import 'package:scissors/src/nullability/runner.dart';

main(List<String> args) async {
  for (var i = 0, n = args.length; i < n; i++) {
    Source source;
    if (args[i] == '-e') {
      source = new StringSource(args[++i], 'input.dart');
    } else {
      source =
          new FileSource(PhysicalResourceProvider.INSTANCE.getFile(args[i]));
    }
    print(await annotateSourceWithNullability(source));
  }
}

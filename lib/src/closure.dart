library scissors;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:scissors/src/io_utils.dart';

Future<String> simpleClosureCompile(String closureCompilerJarPath, String content) async {
  var p = await Process.start('java', [
      '-jar',
      closureCompilerJarPath,
      '--language_in=ES5',
      '--language_out=ES5',
      '-O', 'SIMPLE'
  ], mode: ProcessStartMode.DETACHED_WITH_STDIO);

  p.stdin.writeln(content);
  p.stdin.close();

  var out = readAll(p.stdout);
  var err = readAll(p.stderr);

  if ((await p.exitCode ?? 0) != 0) {
    var errStr = new Utf8Decoder().convert(await err);
    throw new ArgumentError('Failed to run Closure Compiler (exit code = ${await p.exitCode}):\n$errStr');
  }
  return new Utf8Decoder().convert(await out);
}

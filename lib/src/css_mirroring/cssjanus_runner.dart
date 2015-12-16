library scissors.src.css_mirroring.cssjanus_runner;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../utils/io_utils.dart';

/// Executes cssjanus(https://github.com/cegov/wiki/tree/master/maintenance/cssjanus).
/// Input: [source] css and [cssJanusPath] which points to an executable.
/// Pipes in the source css to cssjanus.
/// Output: css flipped from ltr to rtl orientation and vice-versa.
Future<String> runCssJanus(String source, String cssJanusPath) async {
  Process process = await Process.start(cssJanusPath, []);

  new Stream.fromIterable([UTF8.encode(source)])
    ..pipe(process.stdin);

  // TODO(ochafik): Extract some common process util.
  var out = readAll(process.stdout);
  var err = readAll(process.stderr);
  if ((await process.exitCode ?? 0) != 0) {
    var errStr = new Utf8Decoder().convert(await err);
    throw new ArgumentError(
        'Failed to run Closure Compiler (exit code = ${await process
            .exitCode}):\n$errStr');
  }
  var sourceFlipped = await new Utf8Decoder().convert(await out);
  return sourceFlipped;
}

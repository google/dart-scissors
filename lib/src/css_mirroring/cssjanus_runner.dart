library scissors.src.css_mirroring.cssjanus_runner;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../utils/io_utils.dart';

/// Runs cssjanus (https://github.com/cegov/wiki/tree/master/maintenance/cssjanus)
/// on [css], and returns the flipped CSS.
///
/// [cssJanusPath] points to an executable.
Future<String> runCssJanus(String css, String cssJanusPath) async {
  Process process = await Process.start(cssJanusPath, []);

  new Stream.fromIterable([UTF8.encode(css)]).pipe(process.stdin);

  // TODO(ochafik): Extract some common process util.
  var out = readAll(process.stdout);
  var err = readAll(process.stderr);
  if ((await process.exitCode ?? 0) != 0) {
    var errStr = new Utf8Decoder().convert(await err);
    throw new ArgumentError(
        'Failed to run Closure Compiler (exit code = ${await process
            .exitCode}):\n$errStr');
  }
  return new Utf8Decoder().convert(await out);
}

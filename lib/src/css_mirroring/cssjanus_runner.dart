library scissors.src.css_mirroring.cssjanus_runner;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../utils/io_utils.dart';
import 'transformer.dart' show CssMirroringSettings;

// Executes cssJanus and returns flipped css.
runCssJanus(String source, CssMirroringSettings settings) async {
  var cssJanusPath = settings.cssJanusPath.value;
  Process process = await Process.start(cssJanusPath, []);

  Stream<List<int>> stream = new Stream.fromIterable([UTF8.encode(source)]);
  stream.pipe(process.stdin);

  var out = readAll(process.stdout);
  var err = readAll(process.stderr);
  if ((await process.exitCode ?? 0) != 0) {
    var errStr = new Utf8Decoder().convert(await err);
    throw new ArgumentError(
        'Failed to run Closure Compiler (exit code = ${await process
            .exitCode}):\n$errStr');
  }
  var sourceFlipped = new Utf8Decoder().convert(await out);
  return sourceFlipped;
}

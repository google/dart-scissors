// Copyright 2015 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
library scissors.src.compass.compass_runner;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:barback/barback.dart' show Asset, AssetId;
import 'package:scissors/src/image_inlining/main.dart';

import 'args.dart';
import '../utils/io_utils.dart';

enum Compiler { SassC, SassCWithInlineImage, RubySass }

class CompilationResult {
  final Compiler compiler;
  final String stdout;
  final String stderr;
  final int exitCode;
  CompilationResult(this.compiler, this.stdout, this.stderr, this.exitCode);
}

main(List<String> args) async {
  var result = await compile(new SassArgs.parse(args), readStdinSync());
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  exit(result.exitCode);
}

Future<CompilationResult> compile(SassArgs args, input) async {
  if (input is String) input = new Utf8Encoder().convert(input);

  ProcessResult result;
  CompilationResult wrapResult(Compiler compiler) => new CompilationResult(
      compiler, result.stdout, result.stderr, result.exitCode);

  result =
      await _runCommand(args.sasscCommand, input: input, verbose: args.verbose);
  if (result.exitCode == 0) {
    if (args.supportInlineImage) {
      var input = args.output != null
          ? makeFileAsset(args.output)
          : makeStdinAsset(result.stdout);
      var output = await inlineImagesWithIncludeDirs(input, args.includeDirs);
      // Fail fast if there was no change.
      if (output == null) return wrapResult(Compiler.SassC);

      result = await _pipeResult(output, args.output, result.stderr);
      return wrapResult(Compiler.SassCWithInlineImage);
    } else {
      return wrapResult(Compiler.SassC);
    }
  }

  if (!args.fallbackToSass) return wrapResult(Compiler.SassC);

  if (!args.silentSasscErrors) {
    var errors = result.stderr.trim();
    if (errors.isNotEmpty) {
      stderr.writeln(errors.split('\n')
          .map((s) => 'WARNING: [SassC] $s').join('\n'));
    }
    stderr.writeln('WARNING: SassC failed... running Sass');
  }

  result = await _runCommand(args.rubySassCommand, input: input, verbose: args.verbose);
  return wrapResult(Compiler.RubySass);
}

Future<ProcessResult> _pipeResult(
    Asset outputAsset, File outputFile, String stderr) async {
  String stdout;
  if (outputFile != null) {
    outputAsset.read().pipe(outputFile.openWrite());
    stdout = '';
  } else {
    stdout = await outputAsset.readAsString();
  }
  return new ProcessResult(0, 0, stdout, stderr);
}

Future<ProcessResult> _runCommand(List<String> command,
    {List<int> input, bool verbose: false}) async {
  // print('RUNNING: ${command.map((s) => "'$s'").join(' ')}');
  Stopwatch stopwatch;
  if (verbose) stopwatch = new Stopwatch()..start();
  var p = await Process.start(command.first, command.skip(1).toList(),
      workingDirectory: Directory.current.path,
      mode: ProcessStartMode.DETACHED_WITH_STDIO);

  var out = readAll(p.stdout);
  var err = readAll(p.stderr);
  p.stdin
    ..add(input)
    ..close();

  var outStr = new Utf8Decoder().convert(await out);
  var errStr = new Utf8Decoder().convert(await err);

  var exitCode = await p.exitCode ?? (errStr.trim().isEmpty ? 0 : -1);
  if (verbose) {
    stopwatch.stop();
    stderr.writeln(
        'INFO: Command ${command.map((s) => "'$s'").join(' ')} took ${stopwatch.elapsedMilliseconds}ms');
  }
  // print("out: $outStr");
  // print("err: $errStr");
  return new ProcessResult(p.pid, exitCode, outStr, errStr);
}

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
import 'dart:io';

import 'package:barback/barback.dart' show Asset, AssetId;
import 'package:quiver/check.dart';
import 'package:path/path.dart';

import 'args.dart';
import '../image_inlining/main.dart';

enum Compiler { SassC, SassCWithInlineImage, RubySass }

class CompilationResult {
  final Compiler compiler;
  final String stdout;
  final String stderr;
  final int exitCode;
  CompilationResult(this.compiler, this.stdout, this.stderr, this.exitCode);
}

main(List<String> args) async {
  try {
    var opts = new SassArgs.parse(args);
    checkState(opts.input != null, message: () => "Input file argument is mandatory");
    var input = await opts.input?.readAsBytes();// ?? readStdinSync();
    var result = await compile(opts, input);
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    exit(result.exitCode);
  } finally {
    deleteTempDir();
  }
}

Directory _tempDir;
Directory get tempDir => _tempDir ??= Directory.systemTemp.createTempSync();

void deleteTempDir() {
  if (_tempDir == null) return;
  var d = _tempDir;
  _tempDir = null;
  d.listSync().forEach((f) => f.deleteSync());
  d.deleteSync();
}

Future<CompilationResult> compile(SassArgs args, List<int> input) async {
  ProcessResult result;
  CompilationResult wrapResult(Compiler compiler) => new CompilationResult(
      compiler, result.stdout, result.stderr, result.exitCode);

  if (args.input == null) {
    var file = join(tempDir.path, 'input.scss');
    args.input = new File(file)..writeAsBytesSync(input);
    args.options.add(file);
  }

  result = await _runCommand(await args.getSasscCommand(), verbose: args.verbose);
  result = _fixSassCExitCode(result);
  if (result.exitCode == 0) {
    if (args.supportInlineImage) {
      var input = args.output != null
          ? makeFileAsset(args.output)
          : makeStringAsset('<stdin>', result.stdout);
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
      stderr.writeln(
          errors.split('\n').map((s) => 'WARNING: [SassC] $s').join('\n'));
    }
    stderr.writeln('WARNING: SassC failed (result.exitCode = ${result.exitCode}, stderr = ${result.stderr}, stdout = ${result.stdout})... running Sass');
  }

  result = await _runCommand(await args.getRubySassCommand(), verbose: args.verbose);
  return wrapResult(Compiler.RubySass);
}

ProcessResult _fixSassCExitCode(ProcessResult result) {
  var err = result.stderr;
  var exitCode = result.exitCode ??
      ((err.startsWith('Error: ') || err.contains('\nError: ')) ? -1 : 0);
  // print('EXIT CODE($exitCode, fixed from ${result.exitCode}): error.length = ${err.length}\n\t${err.replaceAll('\n', '\n\t')}');
  return new ProcessResult(result.pid, exitCode, result.stdout, result.stderr);
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
    {bool verbose: false}) async {
  Stopwatch stopwatch;
  var commandStr = command.map((s) => "'$s'").join(' ');
  if (verbose) {
    stderr.writeln('INFO: Starting command $commandStr');
    stopwatch = new Stopwatch()..start();
  }
  var result = await Process.run(command.first, command.skip(1).toList(),
      workingDirectory: Directory.current.path);

  if (verbose) {
    stopwatch.stop();
    stderr.writeln(
        'INFO: Command $commandStr took ${stopwatch.elapsedMilliseconds}ms');
  }
  return result;
}

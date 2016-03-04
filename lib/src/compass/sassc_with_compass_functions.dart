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

import 'package:args/args.dart';
import 'package:barback/barback.dart' show Asset, AssetId;
import 'package:quiver/check.dart';

import '../image_inlining/main.dart';
import '../utils/io_utils.dart';
import '../utils/path_resolver.dart';
import '../utils/ruby_gem_utils.dart';

main(List<String> args) async {
  try {
    var opts = new SassCArgs.parse(args);
    if (opts.input == null) {
      var stdin = readStdinSync();
      if (stdin != null) opts.addInput('stdin.scss', stdin);
    }

    ProcessResult result = await Process.run(
        await pathResolver.resolveExecutable(pathResolver.defaultSassCPath),
        [
          '-I',
          await pathResolver.resolvePath(
              pathResolver.defaultCompassStylesheetsPath ??
              _findCompassStylesheets(pathResolver.defaultGemPath).path)
        ]..addAll(opts.args));

    if (result.exitCode == 0) {
      var input = opts.output != null
          ? makeFileAsset(opts.output)
          : makeStringAsset('<stdin>', result.stdout);
      var output = await inlineImagesWithIncludeDirs(
          input, opts.includeDirs.map((path) => new Directory(path)).toList());
      if (output != null) {
        result = await _pipeResult(output, opts.output, result.stderr);
      }
    }

    stdout.write(result.stdout);
    stderr.write(result.stderr);
    exit(result.exitCode);
  } finally {
    deleteTempDir();
  }
}

ArgParser _createSassCArgsParser() {
  return new ArgParser(allowTrailingOptions: true)
    ..addFlag('line-comments')
    ..addFlag('help', abbr: 'h')
    ..addFlag('line-numbers', abbr: 'l')
    ..addFlag('omit-map-comment', abbr: 'M')
    ..addFlag('precision', abbr: 'p')
    ..addFlag('stdin', abbr: 's')
    ..addFlag('version', abbr: 'v')
    ..addOption('load-path', abbr: 'I', allowMultiple: true)
    ..addOption('style',
        abbr: 't', allowed: ['nested', 'compact', 'compressed', 'expanded'])
    ..addOption('sourcemap',
        abbr: 'm', allowed: ['auto', 'file', 'inline', 'none']);
}

class SassCArgs {
  final List<String> args;
  final List<String> includeDirs;
  File input;
  final File output;
  SassCArgs(this.args, {this.includeDirs, this.input, this.output});

  factory SassCArgs.parse(List<String> args) {
    var results = _createSassCArgsParser().parse(args);
    File input;
    File output;
    switch (results.rest.length) {
      case 1:
        input = new File(results.rest[0]);
        break;
      case 2:
        input = new File(results.rest[0]);
        output = new File(results.rest[1]);
        break;
      case 0:
        break;
      default:
        throw new ArgumentError(
            'Expecting 0, 1 or 2 arguments ([input] [output]), got ${results.arguments}');
    }
    return new SassCArgs(
        new List.from(args),
        includeDirs: results['load-path'],
        input: input,
        output: output);
  }

  void addInput(String name, List<int> content) {
    checkState(input == null);
    var file = makeTempFile(name, content);
    input = file;
    args.add(file.path);
  }
}

Directory _findCompassStylesheets(String gemPath) {
  var dir = new Directory(
      getGemPath(gemPath, gemName: 'compass-core', path: 'stylesheets'));
  if (!dir.existsSync()) throw new ArgumentError('Directory not found: $dir');
  return dir;
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

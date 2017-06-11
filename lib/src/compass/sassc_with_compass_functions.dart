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
import 'package:barback/barback.dart' show Asset;
import 'package:quiver/check.dart';

import '../css_mirroring/bidi_css_generator.dart';
import '../css_mirroring/cssjanus_runner.dart';
import '../image_inlining/main.dart';
import '../utils/io_utils.dart';
import '../utils/path_resolver.dart';
import '../utils/ruby_gem_utils.dart';

Directory _findCompassStylesheets(String gemPath) {
  var dir = new Directory(
      getGemPath(gemPath, gemName: 'compass-core', path: 'stylesheets'));
  if (!dir.existsSync()) throw new ArgumentError('Directory not found: $dir');
  return dir;
}

final String compassStylesheetsPath =
    pathResolver.defaultCompassStylesheetsPath ??
        _findCompassStylesheets('gem')?.path;

main(List<String> args) async {
  try {
    final result = await runWithArgs(args);
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    exit(result.exitCode);
  } finally {
    deleteTempDir();
  }
}

Future<ProcessResult> runWithArgs(List<String> args) async {
  args = ['-I', compassStylesheetsPath]..addAll(args);

  var opts = new SassCArgs.parse(args);
  if (opts.inputFile == null) {
    var stdin = readStdinSync();
    if (stdin != null) opts.setInput('stdin.scss', stdin);
  }

  ProcessResult result = await Process.run(
      await pathResolver.resolveExecutable(pathResolver.defaultSassCPath),
      opts.args);

  if (result.exitCode == 0) {
    var input = opts.outputFile != null
        ? makeFileAsset(opts.outputFile)
        : makeStringAsset('<stdin>', result.stdout);
    var output = await inlineImagesWithIncludeDirs(
        input, opts.includeDirs.map((path) => new Directory(path)).toList());
    if (output != null) {
      final cssJanusPath =
          opts.cssjanusPath?.path ?? pathResolver.defaultCssJanusPath;
      if (opts.cssjanusDirection == 'rtl') {
        final inlined = await output.readAsString();
        final flipped = await runCssJanus(inlined, cssJanusPath);
        output = new Asset.fromString(output.id, flipped);
      } else if (opts.cssjanusDirection == 'bidi') {
        final inlined = await output.readAsString();
        final bidirectionalized =
            await bidirectionalizeCss(inlined, (String css) async {
          return runCssJanus(css, cssJanusPath);
        });
        output = new Asset.fromString(output.id, bidirectionalized);
      }
      result = await _pipeResult(output, opts.outputFile, result.stderr);
    }
  }
  return result;
}

ArgParser _createSassCArgsParser() {
  return new ArgParser(allowTrailingOptions: true)
    ..addFlag('help', abbr: 'h')
    ..addFlag('line-comments')
    ..addFlag('line-numbers', abbr: 'l')
    ..addFlag('omit-map-comment', abbr: 'M')
    ..addFlag('stdin', abbr: 's')
    ..addFlag('version', abbr: 'v')
    ..addFlag('sourcemap', abbr: 'm')
    ..addOption('cssjanus-path')
    ..addOption('cssjanus-direction', allowed: ['ltr', 'rtl', 'bidi'])
    ..addOption('load-path', abbr: 'I', allowMultiple: true)
    ..addOption('plugin-path', abbr: 'P')
    ..addOption('precision', abbr: 'p')
    ..addOption('style',
        abbr: 't', allowed: ['nested', 'compact', 'compressed', 'expanded']);
}

/// Representation of SassC's args, with easy access to optional input / output
/// files and include directories.
class SassCArgs {
  final List<String> args;
  final List<String> includeDirs;
  final File cssjanusPath;
  final String cssjanusDirection;
  File inputFile;
  final File outputFile;
  SassCArgs(this.args,
      {this.includeDirs,
      this.inputFile,
      this.outputFile,
      this.cssjanusPath,
      this.cssjanusDirection});

  factory SassCArgs.parse(List<String> args) {
    var results = _createSassCArgsParser().parse(args);
    File inputFile;
    File outputFile;
    switch (results.rest.length) {
      case 1:
        inputFile = new File(results.rest[0]);
        break;
      case 2:
        inputFile = new File(results.rest[0]);
        outputFile = new File(results.rest[1]);
        break;
      case 0:
        break;
      default:
        throw new ArgumentError(
            'Expecting 0, 1 or 2 arguments ([input] [output]),'
            'got ${results.arguments}');
    }

    final cssjanusPath = results['cssjanus-path'];
    final cssjanusDirection = results['cssjanus-direction'];
    return new SassCArgs(
        args.where((a) => !a.startsWith('--cssjanus-')).toList(),
        includeDirs: results['load-path'] as List<String>,
        inputFile: inputFile,
        outputFile: outputFile,
        cssjanusPath: cssjanusPath == null ? null : new File(cssjanusPath),
        cssjanusDirection: cssjanusDirection);
  }

  void setInput(String name, List<int> content) {
    checkState(inputFile == null);
    var tempFile = makeTempFile(name, content);
    inputFile = tempFile;
    args.add(tempFile.path);
  }
}

Future<ProcessResult> _pipeResult(
    Asset outputAsset, File outputFile, String stderr) async {
  String stdout;
  if (outputFile != null) {
    await outputFile.writeAsString(await outputAsset.readAsString(),
        flush: true);
    stdout = '';
  } else {
    stdout = await outputAsset.readAsString();
  }
  return new ProcessResult(0, 0, stdout, stderr);
}

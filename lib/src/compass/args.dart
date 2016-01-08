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
library scissors.src.compass.args;

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:quiver/check.dart';
import 'package:quiver/iterables.dart';

import '../utils/io_utils.dart';
import '../utils/path_resolver.dart';
import '../utils/ruby_gem_utils.dart';

ArgParser _createArgsParser() {
  return new ArgParser(allowTrailingOptions: true)
    ..addFlag('compass')
    ..addFlag('poll')
    ..addFlag('scss')
    ..addFlag('stop-on-error')
    ..addFlag('trace')
    ..addFlag('unix-newlines')
    ..addFlag('line-comments')
    ..addFlag('help2', abbr: '?')
    ..addFlag('help', abbr: 'h')
    ..addFlag('check', abbr: 'c')
    ..addFlag('no-cache', abbr: 'C')
    ..addFlag('force', abbr: 'f')
    ..addFlag('debug-info', abbr: 'g')
    ..addFlag('interactive', abbr: 'i')
    ..addFlag('line-numbers', abbr: 'l')
    ..addFlag('omit-map-comment', abbr: 'M')
    ..addFlag('precision', abbr: 'p')
    ..addFlag('quiet', abbr: 'q')
    ..addFlag('stdin', abbr: 's')
    ..addFlag('version', abbr: 'v')
    ..addOption('default-encoding', abbr: 'E')
    ..addOption('load-path', abbr: 'I', allowMultiple: true)
    ..addOption('require', abbr: 'r')
    ..addOption('style',
        abbr: 't', allowed: ['nested', 'compact', 'compressed', 'expanded'])
    ..addOption('cache-location')
    ..addOption('sourcemap',
        abbr: 'm', allowed: ['auto', 'file', 'inline', 'none'])
    ..addOption('update', allowMultiple: true)
    ..addOption('watch', allowMultiple: true);
}

class SassArgs {
  final ArgResults _results;

  /// Options that are valid for both Ruby Sass and SassC.
  /// (don't include options such as --compass, for instance)
  final List<String> args;
  File input;
  final File output;
  SassArgs(this._results, this.args, {this.input, this.output});

  factory SassArgs.parse(List<String> args) {
    args = _cleanupOptionsForRubySass(args);

    var results = _createArgsParser().parse(args);
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
    return new SassArgs(results, args, input: input, output: output);
  }

  void addInput(String name, List<int> content) {
    checkState(input == null);
    var file = makeTempFile('input.scss', content);
    input = file;
    args.add(file.path);
  }

  String get gem => pathResolver.defaultGemPath;
  String get sass => pathResolver.defaultRubySassPath;
  String get sassc => pathResolver.defaultSassCPath;
  String get ruby => pathResolver.defaultRubyPath;
  String get compassStylesheets {
    var path = pathResolver.defaultCompassStylesheetsPath;
    if (path == null) {
      path = _findCompassStylesheets(gem).path;
      if (quiet) {
        stderr.writeln('INFO: Found Compass stylesheets at $path');
      }
    }
    return path;
  }

  List<String> get includeDirs => _results['load-path'];

  bool get quiet => _results['quiet'];
  bool get useCompass => _results['compass'];

  static List<String> _cleanupOptionsForRubySass(List<String> args) {
    args = []..addAll(args);

    replaceSourcemapOption() {
      int i = args.indexOf('--sourcemap');
      if (i < 0) i = args.indexOf('-M');
      if (i >= 0) args[i] = '--sourcemap=auto';
    }

    replaceSourcemapOption();

    return args;
  }

  /// SassC recognizes a subset of Ruby Sass's options, and some options have
  /// different syntax.
  static List<String> _cleanupRubySassOptionsForSassC(List<String> args) =>
      args.where((o) => o != '--compass' && o != '--scss').map((o) {
        if (o.startsWith('--sourcemap')) {
          return o.substring(0, '--sourcemap'.length);
        }
        return o;
      }).toList();

  Future<List<String>> getSasscCommand() async => concat([
        [await pathResolver.resolveExecutable(sassc)],
        useCompass
            ? ['-I', await pathResolver.resolvePath(compassStylesheets)]
            : [],
        // Removing unavailable options and fixing options with different syntaxes.
        _cleanupRubySassOptionsForSassC(args)
      ]).toList();

  Future<List<String>> getRubySassCommand() async => concat([
        [
          await pathResolver.resolveExecutable(ruby),
          await pathResolver.resolveExecutable(sass)
        ],
        args
      ]).toList();
}

Directory _findCompassStylesheets(String gemPath) {
  var dir = new Directory(
      getGemPath(gemPath, gemName: 'compass-core', path: 'stylesheets'));
  if (!dir.existsSync()) throw new ArgumentError('Directory not found: $dir');
  return dir;
}

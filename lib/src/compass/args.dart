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

import 'dart:io';

import 'package:args/args.dart';
import 'package:quiver/iterables.dart';

import '../utils/ruby_gem_utils.dart';
import 'package:scissors/src/utils/process_utils.dart';
import 'package:scissors/src/utils/path_resolver.dart';
import 'dart:async';

ArgParser _createArgsParser() {
  var parser = new ArgParser(allowTrailingOptions: true)
    ..addFlag('support_inline_image', defaultsTo: true)
    ..addFlag('fallback_to_sass', defaultsTo: true)
    ..addFlag('verbose', defaultsTo: false)
    ..addFlag('silent_sassc_errors', defaultsTo: false)
    ..addOption('gem', defaultsTo: 'gem')
    ..addOption('ruby', defaultsTo: pathResolver.defaultRubyPath)
    ..addOption('sass', defaultsTo: pathResolver.defaultSassPath)
    ..addOption('sass_with_compass', defaultsTo: pathResolver.defaultSassWithCompassPath)
    ..addOption('sassc', defaultsTo: pathResolver.defaultSassCPath)
    ..addOption('compass_stylesheets');
  return parser;
}

class SassArgs {
  final ArgResults _results;

  /// Options that are valid for both Ruby Sass and SassC.
  /// (don't include options such as --compass, for instance)
  final List<String> options;
  File input;
  final File output;
  final bool useCompass;
  final bool scssSyntax;
  final List<Directory> includeDirs;
  SassArgs(this._results, this.options,
      {this.input,
      this.output,
      this.useCompass: false,
      this.includeDirs: const [],
      this.scssSyntax: false});

  factory SassArgs.parse(List<String> args) {
    if (!args.contains('--')) args = ['--']..addAll(args);

    var results = _createArgsParser().parse(args);
    var options = <String>[];
    File input;
    File output;
    bool useCompass = false;
    bool scssSyntax = false;
    var includeDirs = <Directory>[];
    int iArg = 0;
    for (var arg in results.rest) {
      if (arg == '--compass') {
        useCompass = true;
      } else if (arg == '--scss') {
        scssSyntax = true;
      } else {
        options.add(arg);
        if (arg == '-I') {
          includeDirs.add(new Directory(results.rest[iArg + 1]));
        }
      }
      iArg++;
    }

    // Find the extra args (input, output) after the options
    int argsOffset = 0;
    while (argsOffset < options.length) {
      var arg = options[argsOffset];
      if (!arg.startsWith('-')) break;

      argsOffset++;
      if (arg == '-I' || arg == '--load-path' ||
          arg == '-t' || arg == '--style' ||
          arg == '-r' || arg == '--require' ||
          arg == '-E' || arg == '--default-encoding' ||
          arg == '--precision' ||
          arg == '--cache-location') {
        argsOffset++;
      }
    }
    var remainingArgsCount = options.length - argsOffset;
    switch (remainingArgsCount) {
      case 1:
        input = new File(options[options.length - 1]);
        break;
      case 2:
        input = new File(options[options.length - 2]);
        output = new File(options[options.length - 1]);
        break;
      default:
        throw new ArgumentError('Expecting 1 or 2 arguments (input [output]), got $remainingArgsCount: ${options}');
    }
    return new SassArgs(results, options,
        input: input,
        output: output,
        useCompass: useCompass,
        scssSyntax: scssSyntax,
        includeDirs: includeDirs);
  }

  bool get supportInlineImage => _results['support_inline_image'];
  String get gem => _results['gem'];
  String get sass => _results['sass'] ?? which('sass');
  String get sassc => _results['sassc'];
  String get ruby => _results['ruby'];
  String get compassStylesheets {
    var path = _results['compass_stylesheets'];
    if (path == null) {
      path = _findCompassStylesheets(gem).path;
      if (verbose) {
        stderr.writeln('INFO: Found Compass stylesheets at $path');
      }
    }
    return path;
  }

  bool get fallbackToSass => _results['fallback_to_sass'];
  bool get verbose => _results['verbose'];
  bool get silentSasscErrors => _results['silent_sassc_errors'];

  Future<List<String>> getSasscCommand() async => concat([
        [await pathResolver.resolveExecutable(sassc)],
        useCompass ? ['-I', compassStylesheets] : [],
        options
      ]).toList();

  Future<List<String>> getRubySassCommand() async => concat([
        [
            await pathResolver.resolveExecutable(ruby),
            await pathResolver.resolveExecutable(sass)
        ],
        scssSyntax ? ['--scss'] : [],
        useCompass ? ['--compass'] : [],
        options
      ]).toList();
}

Directory _findCompassStylesheets(String gemPath) {
  var dir = new Directory(
      getGemPath(gemPath, gemName: 'compass-core', path: 'stylesheets'));
  if (!dir.existsSync()) throw new ArgumentError('Directory not found: $dir');
  return dir;
}

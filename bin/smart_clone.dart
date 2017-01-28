#!/usr/bin/env dart
// Copyright 2017 Google Inc. All Rights Reserved.
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

import 'dart:async';
import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart';

final argParser = new ArgParser(allowTrailingOptions: true)
  ..addOption('replace', allowMultiple: true)
  ..addOption('edit-command',
      help:
          'Command to run on existing files. The path of the file is appended to the command')
  ..addOption('add-command',
      help:
          'Command to run on added files. The path of the file is appended to the command')
  ..addFlag('inflections',
      negatable: true,
      defaultsTo: true,
      help:
          'Automatically replace inflections such as plurals, gerunds, etc (e.g. "bazzing" for "baz", "vertices" for "vertex", etc)')
  ..addFlag('strict',
      help:
          'Avoids matching Fooa with Foo (but FooBar will still be matched by Foo)')
  ..addFlag('dry-run')
  ..addFlag('verbose', abbr: 'v');

main(List<String> args) async {
  final argResults = argParser.parse(args);

  final editCommand = argResults['edit-command'];
  final addCommand = argResults['add-command'];
  final dryRun = argResults['dry-run'];
  final verbose = argResults['verbose'];
  final strict = argResults['strict'];
  final allowInflections = argResults['inflections'];

  if (argResults.rest.length != 2)
    throw 'Invalid arguments: expected `from to`, got `${argResults.rest.join(' ')}`';

  String from = argResults.rest[0];
  String to = argResults.rest[1];

  final replacer =
      new Replacer(strict: strict, allowInflections: allowInflections);
  replacer.addReplacements(
      basenameWithoutExtension(from), basenameWithoutExtension(to));

  for (final repl in argResults['replace'] ?? []) {
    final split = repl.split(':');
    if (split.length != 2)
      throw 'Invalid replacement format: expected `from:to`, got `$repl`';
    replacer.addReplacements(split[0], split[1]);
  }

  String replacePath(String path) {
    path = absolute(path);
    final rel = relative(path, from: from);
    return rel == '.' ? replacer(to) : join(to, replacer(rel));
  }

  Future runCommand(String command, File file) async {
    final args = command.split(' ');
    final result = await Process.run(
        args.first,
        []
          ..addAll(args.skip(1))
          ..add(file.path));
    if (result.exitCode == 0) {
      stdout.write(result.stdout);
    } else {
      stderr.writeln(
          'Command `$command` failed on ${file.path}:\n${result.stderr}');
    }
  }

  Future<FileClone> cloneFile(File file) async {
    final newFile = new File(replacePath(file.path));
    try {
      final content = await file.readAsString();
      final newContent = replacer(content);
      if (!identical(newContent, content)) {
        return new FileClone(file, newFile, () async {
          await newFile.parent.create(recursive: true);
          if (editCommand != null && await newFile.exists()) {
            await runCommand(editCommand, newFile);
          }
          await newFile.writeAsString(newContent);
          if (addCommand != null) {
            await runCommand(addCommand, newFile);
          }
        }, newContent);
      }
    } catch (e) {
      print('WARNING[$file]: $e');
    }
    return new FileClone(file, newFile, () async {
      await newFile.parent.create(recursive: true);
      await file.copy(newFile.path);
    });
  }

  final cloneFutures = <Future<FileClone>>[];
  final fromEntity = await stat(from);
  if (fromEntity is Directory) {
    await for (final file in fromEntity.list(recursive: true)) {
      if (file.path.contains('/.')) continue;
      if (file is File) {
        cloneFutures.add(cloneFile(file));
      }
    }
  } else {
    cloneFutures.add(cloneFile(fromEntity));
  }
  final clones = await Future.wait(cloneFutures);
  if (dryRun || verbose) printClones(clones);
  if (verbose) print(replacer);
  if (dryRun) return;

  await Future.wait(clones.map((c) => c.perform()));
}

printClones(List<FileClone> clones) {
  for (final clone in clones) {
    print('CLONE: ${clone.original} -> ${clone.destination}');
    print(clone.content);
  }
}

Future<FileSystemEntity> stat(String path) async {
  final s = await FileStat.stat(path);
  switch (s.type) {
    case FileSystemEntityType.FILE:
      return new File(path);
    case FileSystemEntityType.DIRECTORY:
      return new Directory(path);
    case FileSystemEntityType.LINK:
      return await stat(await new Link(path).resolveSymbolicLinks());
    case FileSystemEntityType.NOT_FOUND:
      throw 'Not found: $path';
    default:
      throw 'Wrong file type: ${s.type}';
  }
}

typedef Future _Action();

class FileClone {
  final FileSystemEntity original;
  final FileSystemEntity destination;
  final String content;
  final _Action perform;
  FileClone(this.original, this.destination, this.perform, [this.content]);
}

typedef String _StringTransform(String s);

final caseInsensitiveTransforms = <_StringTransform>[
  (s) => s.replaceAll('-', '_'),
  (s) => s.replaceAll('_', '-'),
  (s) => decamelize(s, '_'),
  (s) => decamelize(s, '-'),
];
final caseSensitiveTransforms = <_StringTransform>[
  underscoresToCamel,
  hyphensToCamel,
];
String identity(String s) => s;

class Replacer extends Function {
  final _replacedPatterns = new Set<String>();
  final _replacements = <RegExp, String>{};
  final _patterns = <RegExp>[];
  final bool strict;
  final bool allowInflections;
  Replacer({this.strict, this.allowInflections});

  static const _patternSuffix = r'(?:$|\b|(?=\d|[-_A-Z]))';
  // const patternPrefix = r'(\b|\d|[_A-Z])';

  void addReplacements(String original, String replacement) {
    final variations = allowInflections ? English.inflections : [identity];
    for (final variation in variations) {
      for (final transform in caseSensitiveTransforms) {
        _addReplacement(original, replacement, (s) => transform(variation(s)));
        _addReplacement(
            original, replacement, (s) => capitalize(transform(variation(s))));
        _addReplacement(original, replacement,
            (s) => decapitalize(transform(variation(s))));
      }
      for (final transform in caseInsensitiveTransforms) {
        _addReplacement(original, replacement, (s) => transform(variation(s)));
        _addReplacement(original, replacement,
            (s) => transform(variation(s)).toUpperCase());
        _addReplacement(original, replacement,
            (s) => transform(variation(s)).toLowerCase());
      }
    }
  }

  void _addReplacement(
      String original, String replacement, _StringTransform transform) {
    final transformed = transform(original);

    // if (transformed == original) continue;
    String pattern = transformed + (strict ? _patternSuffix : '');
    if (_replacedPatterns.add(pattern)) {
      final rx = new RegExp(pattern);
      _patterns.add(rx);
      _replacements[rx] = transform(replacement);
    }
  }

  toString() {
    var s = '{\n';
    _replacements.forEach((k, v) {
      s += '  ${k.pattern} -> $v\n';
    });
    s += '}';
    return s;
  }

  String call(String s) {
    for (final pattern in _patterns) {
      s = s.replaceAll(pattern, _replacements[pattern]);
    }
    return s;
  }
}

final _underscoresRx = new RegExp(r'_([a-z])');
final _hyphensRx = new RegExp(r'-([a-z])');
final _camelRx = new RegExp(r'($|\b|[a-z])([A-Z][a-z]+)');

/// 'this_string' -> 'thisString'.
String underscoresToCamel(String s) =>
    s.replaceAllMapped(_underscoresRx, (m) => m.group(1).toUpperCase());

/// 'this-string' -> 'thisString'.
String hyphensToCamel(String s) =>
    s.replaceAllMapped(_hyphensRx, (m) => m.group(1).toUpperCase());

/// 'thisString' -> 'this_string'
String decamelize(String s, [String c = '_']) => s.replaceAllMapped(
    _camelRx, (m) => m.group(1) + c + decapitalize(m.group(2)));

/// Util method for templates to convert 'this_string' to 'ThisString'.
String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
String decapitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

Map<String, String> invertMap(Map<String, String> map) =>
    new Map.fromIterable(map.keys, key: (k) => map[k]);

_stripFinalE(String s) => s.endsWith('e') ? s.substring(0, s.length - 1) : s;

// TODO(ochafik): Use package:inflection.
class English {
  static final inflections = <_StringTransform>[
    identity,
    doubleLetterPluralize,
    pluralize,
    singularize,
    (s) => doubleFinalLetter(_stripFinalE(s)) + 'er',
    (s) => doubleFinalLetter(_stripFinalE(s)) + 'ed',
    (s) => doubleFinalLetter(_stripFinalE(s)) + 'ing',
  ];

  static final doubledConsonants = new Set.from([
    'b', 'd', 'f', 'g', 'l', 'm', 'n', 'p', 't', 'v', 'z',
    // 'c', 'j', 'k', 'q', 's', 'w', 'x', 'r'
  ]);
  static bool shouldDoubleFinalLetter(String s) {
    if (s.length < 2) return false;
    final c = s[s.length - 1];
    final previous = s[s.length - 2];
    return doubledConsonants.contains(c) && c != previous;
  }

  static String doubleFinalLetter(String s) {
    if (shouldDoubleFinalLetter(s)) return s + s[s.length - 1];
    return s;
  }

  static final _knownPlurals = {
    'child': 'children',
    'criterion': 'criteria',
    'foot': 'feet',
    'leaf': 'leaves',
    'life': 'lives',
    'person': 'people',
    'formula': 'formulae',
  };
  static final _knownSingulars = invertMap(_knownPlurals);
  static final _knownPluralSuffices = {
    'ay': 'ays',
    'ey': 'eys',
    'y': 'ies',
    'ix': 'ices',
    'ex': 'ices',
    'is': 'es',
    'ro': 'roes',
    'um': 'a',
    'us': 'i',
    's': 'ses',
    '': 's'
  };
  static final _knownSingularSuffices = invertMap(_knownPluralSuffices);

  static String _replaceSuffix(String s, int length, String to) =>
      s.substring(0, s.length - length) + to;

  static String pluralize(String s) {
    final knownPlural = _knownPlurals[s];
    if (knownPlural != null) return knownPlural;

    if (s.length > 1) {
      for (final suffix in _knownPluralSuffices.keys) {
        if (s.endsWith(suffix)) {
          return _replaceSuffix(s, suffix.length, _knownPluralSuffices[suffix]);
        }
      }
    }
    return s;
  }

  static String singularize(String s) {
    final knownSingular = _knownSingulars[s];
    if (knownSingular != null) return knownSingular;

    if (s.length > 1) {
      for (final suffix in _knownSingularSuffices.keys) {
        if (s.endsWith(suffix)) {
          return _replaceSuffix(
              s, suffix.length, _knownSingularSuffices[suffix]);
        }
      }
    }
    return s;
  }

  static String doubleLetterPluralize(String s) {
    if (shouldDoubleFinalLetter(s)) return doubleFinalLetter(s) + 'es';
    return pluralize(s);
  }
}

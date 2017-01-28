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
  ..addFlag('dry-run');

main(List<String> args) async {
  final argResults = argParser.parse(args);

  if (argResults.rest.length != 2)
    throw 'Invalid arguments: expected `from to`, got `${argResults.rest.join(' ')}`';

  String from = argResults.rest[0];
  String to = argResults.rest[1];

  final replacer = new Replacer();
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

  final editCommand = argResults['edit-command'];
  final addCommand = argResults['add-command'];

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
  if (argResults['dry-run']) {
    for (final clone in clones) {
      print('CLONE: ${clone.original} -> ${clone.destination}');
      print(clone.content);
    }

    print(replacer);
    return;
  }

  await Future.wait(clones.map((c) => c.perform()));
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
  // (s) => s
];
final caseSensitiveTransforms = <_StringTransform>[
  underscoresToCamel,
  hyphensToCamel,
  // capitalize,
  // decapitalize,
];
final variationTransforms = <_StringTransform>[
  (s) => s,
  pluralize,
  (s) => doubleFinalLetter(s, 'er'),
  (s) => doubleFinalLetter(s, 'ed'),
  (s) => doubleFinalLetter(s, 'ing'),
];

class Replacer extends Function {
  final _replacedPatterns = new Set<String>();
  final _replacements = <RegExp, String>{};
  final _patterns = <RegExp>[];

  static const _patternSuffix = r'(?:$|\b|(?=\d|[-_A-Z]))';
  // const patternPrefix = r'(\b|\d|[_A-Z])';

  void addReplacements(String original, String replacement) {
    for (final variation in variationTransforms) {
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
    String pattern = transformed + _patternSuffix;
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

final knownPlurals = {
  'leaf': 'leaves',
  'hero': 'heroes',
  'foot': 'feet',
  'person': 'people',
  'child': 'children',
  'knife': 'knives',
  'life': 'lives',
  'storey': 'storeys',
  'formula': 'formulae',
  'criterion': 'criteria',
};

final doubledConsonants = new Set.from([
  'b', 'd', 'f', 'g', 'l', 'm', 'n', 'p', 'r', 's', 't', 'v', 'z'
  // 'c', 'j', 'k', 'q', 'w', 'x',
]);
String doubleFinalLetter(String s, String suffix) {
  if (s.length < 2) return s;
  final c = s[s.length - 1];
  final previous = s[s.length - 2];
  if (doubledConsonants.contains(c) && c != previous) return s + c + suffix;
  return s + suffix;
}

String pluralize(String s) {
  String replaceSuffix(int length, String to) =>
      s.substring(0, s.length - length) + to;

  final knownPlural = knownPlurals[s];
  if (knownPlural != null) return knownPlural;

  if (s.length > 1) {
    if (s.endsWith('y') && !s.endsWith('ay') && !s.endsWith('ey')) {
      return replaceSuffix(1, 'ies');
    }
    if (s.endsWith('ix') || s.endsWith('ex')) {
      return replaceSuffix(2, 'ices');
    }
    if (s.endsWith('is')) {
      return replaceSuffix(2, 'es');
    }
    if (s.endsWith('ro')) {
      return replaceSuffix(2, 'roes');
    }
    if (s.endsWith('um')) {
      return replaceSuffix(2, 'a');
    }
    if (s.endsWith('us')) {
      return replaceSuffix(2, 'i');
    }
    if (s.endsWith('ies')) {
      return s;
    }
    if (s.endsWith('s') || s.endsWith('es')) {
      return replaceSuffix(0, 'es');
    }
    return s + 's';
  }
  return s;
}

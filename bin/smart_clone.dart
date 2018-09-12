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
import 'package:scissors/src/smart_clone/replacer.dart';

final argParser = new ArgParser(allowTrailingOptions: true)
  ..addFlag('help')
  ..addOption('replace', allowMultiple: true)
  ..addFlag('replaceFromTo',
      defaultsTo: true,
      help: 'Whether to infer replacements from the from & to args')
  ..addOption('edit-command',
      help:
          'Command to run on existing files. The path of the file is appended to the command')
  ..addOption('copy-command',
      help:
          'Command to run on each old/new file pair, to initiate a copy. The path of the files is appended to the command')
  ..addOption('add-command',
      help:
          'Command to run on added files. The path of the file is appended to the command')
  ..addOption('final-command',
      allowMultiple: true,
      help:
          'Command to run on all output files at the end. The path of the all the files is appended to the command')
  ..addFlag('inflections',
      negatable: true,
      defaultsTo: true,
      help:
          'Automatically replace inflections such as plurals, gerunds, etc (e.g. "bazzing" for "baz", "vertices" for "vertex", etc)')
  ..addFlag('strict',
      defaultsTo: true,
      help:
          'Avoids matching Fooa with Foo (but FooBar will still be matched by Foo)')
  ..addFlag('dry-run')
  ..addFlag('verbose', abbr: 'v');

main(List<String> args) async {
  final argResults = argParser.parse(args);

  final editCommand = parseCommand(argResults['edit-command']);
  final copyCommand = parseCommand(argResults['copy-command']);
  final addCommand = parseCommand(argResults['add-command']);
  final finalCommands = (argResults['final-command'] ?? []).map(parseCommand);
  final dryRun = argResults['dry-run'];
  final verbose = argResults['verbose'];
  final strict = argResults['strict'];
  final allowInflections = argResults['inflections'];
  final replaceFromTo = argResults['replaceFromTo'];

  printHelp() {
    print('smart_clone [options] fromPath toPath\n${argParser.usage}');
  }

  if (argResults['help']) {
    printHelp();
    return;
  }
  if (argResults.rest.length != 2) {
    printHelp();
    throw 'Requires both fromPath and toPath arguments.';
  }

  String from = argResults.rest[0];
  String to = argResults.rest[1];

  final replacer =
      new Replacer(strict: strict, allowInflections: allowInflections);
  if (replaceFromTo) {
    replacer.addReplacements(
        basenameWithoutExtension(from), basenameWithoutExtension(to));
    replacer.addReplacements(from, to);
    final fromDir = dirname(from);
    final toDir = dirname(to);
    if (fromDir != '.' && toDir != '.') {
      replacer.addReplacements(fromDir, toDir);
      for (final prefix in [
        'src/',
        'src/main/java/',
        'src/test/java/',
        'java/',
        'javatests/'
      ]) {
        if (fromDir.startsWith(prefix) &&
            fromDir.length > prefix.length &&
            toDir.startsWith(prefix) &&
            toDir.length > prefix.length) {
          replacer.addReplacements(
              fromDir.substring(prefix.length), toDir.substring(prefix.length));
        }
      }
    }
  }

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

  Future runCommand(List<String> command, List<FileSystemEntity> files) async {
    final result = await Process.run(command.first,
        []..addAll(command.skip(1))..addAll(files.map((file) => file.path)));
    if (result.exitCode == 0) {
      stdout.write(result.stdout);
    } else {
      stderr
          .writeln('Command `$command` failed on ${files}:\n${result.stderr}');
    }
  }

  Future<FileClone> cloneFile(File file) async {
    final newFile = new File(replacePath(file.path));

    Future copy() async {
      final existed = await newFile.exists();
      await newFile.parent.create(recursive: true);
      bool copied = false;
      bool edited = false;
      if (copyCommand != null && !existed) {
        await runCommand(copyCommand, [file, newFile]);
        copied = true;
      }
      if (editCommand != null && await newFile.exists()) {
        await runCommand(editCommand, [newFile]);
        edited = true;
      }
      if (!copied) {
        await file.copy(newFile.path);
      }
      if (!existed && !copied && !edited && addCommand != null) {
        await runCommand(addCommand, [newFile]);
      }
    }

    try {
      final content = await file.readAsString();
      final newContent = replacer(content);
      return new FileClone(file, newFile, () async {
        await copy();
        if (content != newContent) {
          await newFile.writeAsString(newContent);
        }
      }, newContent);
    } catch (e) {
      if (verbose) stderr.writeln('WARNING[$file]: $e');
      return new FileClone(file, newFile, () async {
        await copy();
      });
    }
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

  for (final finalCommand in finalCommands) {
    await runCommand(finalCommand, clones.map((c) => c.destination).toList());
  }
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

List<String> parseCommand(String command) {
  if (command == null) return null;
  String currentToken = '';
  String quoteChar;
  final length = command.length;
  final tokens = <String>[];
  int i = 0;
  String c;
  consumeChar() => c = command[i++];
  void flushToken() {
    if (currentToken.isEmpty) return;
    tokens.add(currentToken);
    currentToken = '';
  }

  while (i < length) {
    consumeChar();
    switch (c) {
      case '"':
      case "'":
        quoteChar = c;
        while (i < length) {
          consumeChar();
          if (c == '\\') {
            if (i < length) {
              consumeChar();
              switch (c) {
                case 'n':
                  c = '\n';
                  break;
                case 'r':
                  c = '\r';
                  break;
                case 'b':
                  c = '\b';
                  break;
                case 't':
                  c = '\t';
                  break;
              }
              currentToken += c;
            } else {
              throw 'Invalid escape in command: `$command`';
            }
          } else if (c == quoteChar) {
            break;
          } else {
            currentToken += c;
          }
        }
        break;
      case ' ':
      case '\t':
      case '\n':
      case '\r':
        flushToken();
        break;
      default:
        currentToken += c;
    }
  }
  flushToken();
  return tokens;
}

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
library scissors.src.utils.process_utils;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'io_utils.dart';

String getOutputString(stdio) =>
    stdio is String ? stdio : new Utf8Decoder().convert(stdio as List<int>);

String successString(String command, ProcessResult result) {
  var err = getOutputString(result.stderr).trim();
  var exitCode = result.exitCode ?? (err.isNotEmpty ? -1 : 0);
  if (exitCode != 0) {
    throw new ArgumentError(
        'Failed to run $command (exit code = ${result.exitCode}):\n$err');
  }
  return getOutputString(result.stdout);
}

ProcessResult _which(String path) => Process.runSync('which', [path]);

String which(String path) => successString('which $path', _which(path)).trim();

bool hasExecutable(String name) => _which(name).exitCode == 0;

Future<ProcessResult> pipeInAndOutOfNewProcess(Process p, dynamic input) async {
  if (input is String) {
    p.stdin.write(input);
  } else if (input is List<int>) {
    p.stdin.add(input);
  } else {
    throw new ArgumentError('Unexpected input: ${input.runtimeType}');
  }
  await p.stdin.close();

  var out = readAll(p.stdout);
  var err = readAll(p.stderr);

  return new ProcessResult(p.pid, await p.exitCode, await out, await err);
}

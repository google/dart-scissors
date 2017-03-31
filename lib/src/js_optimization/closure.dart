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
library scissors.src.js_optimization.closure;

import 'dart:async';
import 'dart:io';

import '../utils/process_utils.dart';

Future<String> simpleClosureCompile(
    String javaPath, String closureCompilerJarPath, String content) async {
  var p = await Process.start(javaPath,
      ['-jar', closureCompilerJarPath, '--language_out=ES5', '-O', 'SIMPLE'],
      mode: ProcessStartMode.DETACHED_WITH_STDIO);

  return successString(
      'Closure Compiler', await pipeInAndOutOfNewProcess(p, content));
}

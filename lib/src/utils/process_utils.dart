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

import 'dart:io';

String successString(ProcessResult result) {
  if (result.exitCode != 0) {
    throw new StateError('Exit code: ${result.exitCode}\n${result.stderr}');
  }
  return result.stdout;
}

ProcessResult _which(String path) => Process.runSync('which', [path]);

String which(String path) => successString(_which(path)).trim();

bool hasExecutable(String name) => _which(name).exitCode == 0;

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
library scissors.src.utils.ruby_gem_utils;

import 'dart:io';
import 'package:path/path.dart';
import 'package:quiver/check.dart';
import 'process_utils.dart';

final RegExp _gemVersionRx = new RegExp(r'^([\w-]+)\s*\(([^)]+)\)$');

List<String> getGemVersions(String gemPath, String gemName) {
  var result = successString('gem list $gemName',
      Process.runSync(gemPath, ['list', '-l', '^$gemName\$']));
  // print('gem list ($gemName): $result');
  var versions = <String>[];
  for (var line in result.split('\n')) {
    line = line.trim();
    var m = _gemVersionRx.matchAsPrefix(line);
    if (m == null) {
      if (line.isNotEmpty && !line.startsWith('***')) {
        print('Failed to understand gem list line:\n$line');
      }
      continue;
    }

    var gemNameFound = m[1];
    var version = m[2];
    checkState(gemNameFound == gemName,
        message: () => "Expected $gemName, found $gemNameFound");
    versions.add(version);
  }
  return versions;
}

String getGemPath(String gemPath,
    {String gemName, String path, String gemVersion}) {
  var versions = getGemVersions(gemPath, gemName);
  if (versions.isEmpty) {
    throw new StateError('Ruby gem $gemName does not seem to be installed!');
  }
  // TODO(ochafik): Take the latest version (using semver package).
  gemVersion ??= versions.first;
  var gemDir = successString('gem environment gemdir',
      Process.runSync(gemPath, ['environment', 'gemdir'])).trim();
  return join(gemDir, 'gems', '$gemName-$gemVersion', path);
}

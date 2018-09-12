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

final _underscoresRx = new RegExp(r'_([a-z])');
final _hyphensRx = new RegExp(r'-([a-z])');

typedef String StringTransform(String s);
String identity(String s) => s;

/// 'this_string' -> 'thisString'.
String underscoresToCamel(String s) =>
    s.replaceAllMapped(_underscoresRx, (m) => m.group(1).toUpperCase());

/// 'this-string' -> 'thisString'.
String hyphensToCamel(String s) =>
    s.replaceAllMapped(_hyphensRx, (m) => m.group(1).toUpperCase());

/// 'thisString' -> 'this_string'
String decamelize(String s, [String separator = '_']) {
  final fragments = <String>[];

  var currentFragment = '';
  void flushFragment() {
    if (currentFragment == '') return;
    fragments.add(currentFragment);
    currentFragment = '';
  }

  for (int i = 0, n = s.length; i < n; i++) {
    final c = s[i];
    if (c == c.toUpperCase()) {
      flushFragment();
    }
    currentFragment += c.toLowerCase();
  }
  flushFragment();
  return fragments.join(separator);
}

/// 'a.b' -> 'a/b'
String packageToPath(String s) => s.replaceAll('.', '/');
/// 'a/b' -> 'a.b'
String pathToPackage(String s) => s.replaceAll('/', '.');

/// Util method for templates to convert 'this_string' to 'ThisString'.
String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
String decapitalize(String s) =>
    s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);


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
library scissors.test.path_resolver_test;

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:scissors/src/utils/path_resolver.dart' show pathResolver;
import 'package:scissors/testing/transformer_test_utils.dart';

main() {
  if (Platform.environment['TRAVIS'] == 'true') {
    print("WARNING: Skipping path resolver tests on Travis.");
    return;
  }

  group('pathResolver', () {

    var executables = {
      'sassc': pathResolver.defaultSassCPath,
      'pngcrush': pathResolver.defaultPngCrushPath,
      'cssjanus': pathResolver.defaultCssJanusPath,
      'java': pathResolver.defaultJavaPath,
    };
    var files = {
      'jruby': pathResolver.defaultJRubyPath,
      'ruby sass': pathResolver.defaultRubySassPath,
      'closure': pathResolver.defaultClosureCompilerJarPath
    };
    var dirs = {
      'compass stylesheets': pathResolver.defaultCompassStylesheetsPath,
    };

    check(String kind, String name, String path, Future action(String resolved)) {
      if (path == null) {
        print("WARNING: No path set for $name.");
      } else {
        test('finds $kind $name ($path)', () async {
          var resolved = await pathResolver.resolvePath(path);
          await action(resolved);
        });
      }
    }

    executables.forEach((name, path) {
      check('executable', name, path, (resolved) async {
        expect(hasExecutable(resolved), true);
      });
    });
    files.forEach((name, path) {
      check('file', name, path, (resolved) async {
        expect(await new File(resolved).exists(), true);
      });
    });
    dirs.forEach((name, path) {
      check('directory', name, path, (resolved) async {
        expect(await new Directory(resolved).exists(), true);
      });
    });
  });
}

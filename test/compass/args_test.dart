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
library scissors.test.compass.args_test;

import 'package:test/test.dart';
import 'package:scissors/src/utils/path_resolver.dart';
import 'dart:async';
import 'package:scissors/src/compass/sassc_with_compass_functions.dart';

class FakePathResolver implements PathResolver {
  noSuchMethod(Invocation i) => super.noSuchMethod(i);

  @override
  String get defaultCompassStylesheetsPath => 'test_compass_stylesheets';

  @override
  String get defaultRubyPath => 'test_ruby';

  @override
  String get defaultRubySassPath => 'test_ruby_sass';

  @override
  String get defaultSassCPath => 'test_sassc';

  @override
  Future<String> resolveExecutable(String path) async => 'resolved_exec_$path';

  @override
  Future<String> resolvePath(String path) async => 'resolved_$path';
}

main() {
  group('SassArgs', () {
    parse(List<String> args) => new SassCArgs.parse(args);
    check(List<String> args,
        {String input, String output, List<String> includeDirs: const []}) {
      var p = parse(args);
      expect(p.inputFile?.path, input);
      expect(p.outputFile?.path, output);
      expect(p.includeDirs, includeDirs);
    }

    var originalPathResolver = pathResolver;
    setUp(() {
      pathResolver = new FakePathResolver();
    });
    tearDown(() {
      pathResolver = originalPathResolver;
    });

    test('parses input and output files', () async {
      check([]);
      check(['a'], input: 'a', output: null);
      check(['a', 'b'], input: 'a', output: 'b');
    });
    test('parses includes', () async {
      check(['-I', 'a', '--load-path', 'b'], includeDirs: ['a', 'b']);
    });
    test('validates flags', () async {
      check([
        '--line-comments',
        '--help',
        '-h',
        '--line-numbers',
        '-l',
        '--omit-map-comment',
        '-M',
        '--precision',
        '1',
        '-p',
        '2',
        '--stdin',
        '-s',
        '--version',
        '-v',
        '--sourcemap',
        '-m',
        '--plugin-path',
        '.',
        '-P',
        '.',
        '--style=nested',
        '--style=compact',
        '--style=compressed',
        '-t',
        'expanded',
      ]);
      expect(() => check(['-X']), throws);
    });
  });
}

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

import 'package:scissors/src/compass/args.dart';

import 'package:test/test.dart';
import 'package:scissors/src/utils/path_resolver.dart';
import 'dart:async';

class FakePathResolver implements PathResolver {
  noSuchMethod(Invocation i) => super.noSuchMethod(i);

  @override String get defaultCompassStylesheetsPath =>
      'test_compass_stylesheets';

  @override String get defaultRubyPath => 'test_ruby';

  @override String get defaultRubySassPath => 'test_ruby_sass';

  @override String get defaultSassCPath => 'test_sassc';

  @override String get defaultSassWithCompassPath =>
      'test_ruby_sass_with_compass';

  @override
  Future<String> resolveExecutable(String path) async => 'resolved_exec_$path';

  @override
  Future<String> resolvePath(String path) async => 'resolved_$path';
}

main() {
  group('SassArgs', () {
    parse(List<String> args) => new SassArgs.parse(args);
    check(List<String> args,
        {List<String> sasscCmd,
        List<String> sassCmd,
        String input,
        String output,
        bool useCompass: false,
        bool scssSyntax: false,
        List<String> includeDirs: const []}) async {
      var p = parse(args);
      if (sassCmd != null) expect(await p.getRubySassCommand(), sassCmd);
      if (sasscCmd != null) expect(await p.getSasscCommand(), sasscCmd);
      expect(p.input?.path, input);
      expect(p.output?.path, output);
      expect(p.useCompass, useCompass);
      expect(p.includeDirs, includeDirs);
    }

    var originalPathResolver = pathResolver;
    setUp(() {
      pathResolver = new FakePathResolver();
    });
    tearDown(() {
      pathResolver = originalPathResolver;
    });

    test('parses options and resolves commands', () async {
      await check([],
          sassCmd: ['resolved_exec_test_ruby', 'resolved_exec_test_ruby_sass'],
          sasscCmd: ['resolved_exec_test_sassc'],
          useCompass: false);
      await check(['a'],
          sassCmd:
              ['resolved_exec_test_ruby', 'resolved_exec_test_ruby_sass', 'a'],
          sasscCmd: ['resolved_exec_test_sassc', 'a'],
          input: 'a',
          output: null,
          useCompass: false);
      await check([
        '--compass',
        'a',
        'b'
      ], sassCmd: [
        'resolved_exec_test_ruby',
        'resolved_exec_test_ruby_sass',
        '--compass',
        'a',
        'b'
      ], sasscCmd: [
        'resolved_exec_test_sassc',
        '-I',
        'resolved_test_compass_stylesheets',
        'a',
        'b',
      ], input: 'a', output: 'b', useCompass: true);
    });
    test('parses includes', () async {
      await check(['-I', 'a', '-I', 'b'], includeDirs: ['a', 'b']);
    });
  });
}

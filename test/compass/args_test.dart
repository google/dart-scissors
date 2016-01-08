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

main() {
  group('SassArgs', () {
    parse(List<String> args) => new SassArgs.parse(args);
    check(List<String> args,
        {List<String> options,
        String input,
        String output,
        bool useCompass : false,
        bool scssSyntax : false,
        List<String> includeDirs : const []}) {

      var p = parse(args);
      if (options != null) expect(p.options, options);
      expect(p.input?.path, input);
      expect(p.output?.path, output);
      expect(p.useCompass, useCompass);
      expect(p.scssSyntax, scssSyntax);
      expect(p.includeDirs.map((d) => d.path), includeDirs);
    }
    test('parses options input output', () {
      check(['--', 'a', 'b'],
          options: ['a', 'b'],
          input: 'a',
          output: 'b');
      check(['--foo', 'a', 'b'],
          options: ['--foo', 'a', 'b'],
          input: 'a',
          output: 'b');
      check(['--foo', 'a'],
          options: ['--foo', 'a'],
          input: 'a',
          output: null);
      check(['--foo'],
          options: ['--foo'],
          input: null,
          output: null);
    });
    test('parses compass options', () {
      check(['--compass'], options: [], useCompass: true);
      check(['--', '--compass'], options: [], useCompass: true);
      check([], options: [], useCompass: false);
    });
    test('parses includes', () {
      check(['-I', 'a'], includeDirs: ['a']);
      check(['--', '-I', 'a', '-I', 'b'], includeDirs: ['a', 'b']);
    });
  });
}

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
library scissors.test.compass.sassc_with_compass_fallback_test;

import 'dart:convert';

import 'package:scissors/src/compass/sassc_with_compass_fallback.dart'
    show CompilationResult, Compiler, compile, deleteTempDir;
import 'package:scissors/src/compass/args.dart';
import 'package:scissors/src/utils/io_utils.dart' show deleteTempDir;
import 'package:test/test.dart';

_compile(List<String> args, String input) {
  var opts = new SassArgs.parse(args);
  if (opts.input == null) {
    opts.addInput('test_input.scss', new Utf8Encoder().convert(input));
  }
  return compile(opts);
}

main() {
  tearDown(() {
    deleteTempDir();
  });

  test('succeeds on simple scss', () async {
    var result = await _compile([], '.foo { .bar { float: left; } }');
    expect(result.compiler, Compiler.SassC);
    expect(
        result.stdout,
        '.foo .bar {\n'
        '  float: left; }\n');
  });

  var inlineImageInput = '.foo {\n'
      '  background-image: inline-image("compass/foo.svg"); }\n';

  test('inlines images', () async {
    var result = await _compile(['-I', 'test'], inlineImageInput);
    expect(result.compiler, Compiler.SassCWithInlineImage);
    expect(
        result.stdout,
        '.foo {\n'
        '  background-image: url(\'data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0idXRmLTgiPz4KPHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOnhsaW5rPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5L3hsaW5rIj4KICA8cmVjdCB4PSIwIiB5PSIwIiBoZWlnaHQ9IjEwIiB3aWR0aD0iMTAiIHN0eWxlPSJzdHJva2U6IzAwMDBmZjsgZmlsbDogIzAwZmYwMCIvPgo8L3N2Zz4K\'); }\n');
  });

  test('succeeds with simple compass stylesheets', () async {
    var result = await _compile(
        ['--scss', '--compass'],
        '''
      @import 'compass/layout/stretching';

      .foo {
        @include stretch();
      }
    ''');
    expect(result.compiler, Compiler.SassC);
    expect(
        result.stdout,
        '.foo {\n'
        '  position: absolute;\n'
        '  top: 0;\n'
        '  bottom: 0;\n'
        '  left: 0;\n'
        '  right: 0; }\n');
  });

  test('falls back on sass when hitting problematic syntax', () async {
    var result = await _compile(
        ['--scss', '--compass'],
        '''
      @import 'compass/css3/flexbox';

      :host,
      .options-wrapper {
        @include display-flex(inline-flex);
      }
    ''');
    expect(result.compiler, Compiler.RubySass);
    expect(
        result.stdout,
        ':host,\n'
        '.options-wrapper {\n'
        '  display: -webkit-inline-flex;\n'
        '  display: inline-flex; }\n');
  });
}

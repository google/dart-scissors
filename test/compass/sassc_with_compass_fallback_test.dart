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

import 'package:scissors/src/compass/sassc_with_compass_fallback.dart'
    show compile, CompilationResult, Compiler;
import 'package:scissors/src/compass/args.dart';
import 'package:scissors/src/utils/process_utils.dart';

import 'package:test/test.dart';

_compile(List<String> args, String input) {
  if (!args.contains('--noverbose')) {
    if (!args.contains('--')) args = ['--']..addAll(args);
    args = ['--verbose']..addAll(args);
  }
  return compile(new SassArgs.parse(args), input);
}

main() {
  if (!hasExecutable('gem')) {
    // TODO(ochafik): Find a way to get sassc on travis (if possible,
    // without having to compile it ourselves).
    print("WARNING: Skipping Compass tests by lack of gem in the PATH.");
    return;
  }

  test('succeeds on simple scss', () async {
    var result = await _compile([], '.foo { .bar { float: left; } }');
    expect(result.compiler, Compiler.SassC);
    expect(
        result.stdout,
        '.foo .bar {\n'
        '  float: left; }\n');
  });

  var inlineImageInput = '.foo {\n'
      '  image-background: inline-image("test/compass/foo.svg"); }\n';

  test('inlines images', () async {
    var result = await _compile([], inlineImageInput);
    expect(result.compiler, Compiler.SassCWithInlineImage);
    expect(
        result.stdout,
        '.foo {\n'
        '  image-background: url(\'data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0idXRmLTgiPz4KPHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOnhsaW5rPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5L3hsaW5rIj4KICA8cmVjdCB4PSIwIiB5PSIwIiBoZWlnaHQ9IjEwIiB3aWR0aD0iMTAiIHN0eWxlPSJzdHJva2U6IzAwMDBmZjsgZmlsbDogIzAwZmYwMCIvPgo8L3N2Zz4K\'); }\n');
  });

  test('does not inline image when disabled', () async {
    var result = await _compile(['--no-support_inline_image', '--'], inlineImageInput);
    expect(result.compiler, Compiler.SassC);
    expect(result.stdout, inlineImageInput);
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

  test('fails on display-flex includes', () async {
    var result = await _compile(
        ['--no-fallback_to_sass', '--', '--compass'],
        '''
      @import 'compass/css3/flexbox';

      :host,
      .options-wrapper {
        @include display-flex(inline-flex);
      }
    ''');
    expect(result.compiler, Compiler.SassC);
    expect(result.exitCode, isNot(equals(0)));
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

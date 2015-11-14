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
library scissors.test.sass.transformer_test;

import 'dart:io';

import 'package:barback/barback.dart'
    show BarbackMode, BarbackSettings, Transformer;
import 'package:code_transformers/tests.dart'
    show StringFormatter, applyTransformers;
import 'package:test/test.dart' show test;
import 'package:scissors/src/sass/transformer.dart';

makePhases(Map config) => [[
    new SassTransformer.asPlugin(
        new BarbackSettings(config, BarbackMode.RELEASE))
]];

void main() {
  if (Process.runSync('which', ['sassc']).exitCode != 0) {
    // TODO(ochafik): Find a way to get sassc on travis (if possible,
    // without having to compile it ourselves).
    print("WARNING: Skipping Sass tests by lack of sassc in the PATH.");
    return;
  }
  var phases = makePhases({});

  _testPhases('runs sassc on .scss and .sass inputs', phases, {
    'a|foo.scss': '''
      .foo {
        float: left;
      }
    ''',
    'a|foo.sass': '''
.foo
  height: 100%
    '''
  }, {
    'a|foo.scss.css': '.foo{float:left}\n',
    'a|foo.scss.css.map': '{\n'
        '\t"version": 3,\n'
        '\t"file": "foo.scss.css",\n'
        '\t"sources": [\n'
        '\t\t"foo.scss"\n'
        '\t],\n'
        '\t"sourcesContent": [],\n'
        '\t"mappings": "AAAM,IAAI,AAAC,CACH,KAAK,CAAE,IAAK,CADR",\n'
        '\t"names": []\n'
        '}',
    'a|foo.sass.css': '.foo{height:100%}\n',
    'a|foo.sass.css.map': '{\n'
        '\t"version": 3,\n'
        '\t"file": "foo.sass.css",\n'
        '\t"sources": [\n'
        '\t\t"foo.sass"\n'
        '\t],\n'
        '\t"sourcesContent": [],\n'
        '\t"mappings": "AAAA,IAAI,AAAC,CACH,MAAM,CAAE,IAAK,CADT",\n'
        '\t"names": []\n'
        '}'
  });

  // _testPhases('does not run sassc on .scss that are already converted', phases, {
  //   'a|foo.scss': '''
  //     .foo {
  //       float: left;
  //     }
  //   ''',
  //   'a|foo.scss.css': '/* do not modify */'
  // }, {
  //   'a|foo.scss.css': '/* do not modify */'
  // });

  _testPhases('reports sassc errors properly', phases, {
    'a|foo.scss': '''
      .foo {{
        float: left;
      }
    '''
  }, {}, [
    'error: invalid property name (a%7Cfoo.scss 1 12)'
  ]);
}

_testPhases(String testName, List<List<Transformer>> phases,
    Map<String, String> inputs, Map<String, String> results,
    [List<String> messages,
    StringFormatter formatter = StringFormatter.noTrailingWhitespace]) {
  test(
      testName,
      () async => applyTransformers(phases,
          inputs: inputs,
          results: results,
          messages: messages,
          formatter: formatter));
}

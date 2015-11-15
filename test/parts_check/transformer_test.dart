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
library scissors.test.parts_check.transformer_test;

import 'package:barback/barback.dart'
    show BarbackMode, BarbackSettings, Transformer;
import 'package:code_transformers/tests.dart'
    show StringFormatter, applyTransformers;
import 'package:test/test.dart' show test;
import 'package:scissors/src/parts_check/transformer.dart';

makePhases(Map config) => [
      [
        new PartsCheckTransformer.asPlugin(
            new BarbackSettings(config, BarbackMode.RELEASE))
      ]
    ];

void main() {
  _testPhases(
      'does not warn when part count matches expectation',
      makePhases({
        'expectedPartCounts': {'web/main.dart.js': 2}
      }),
      {'a|web/main.dart.js_1.part.js': '', 'a|web/main.dart.js_2.part.js': ''},
      {},
      []);

  _testPhases(
      'fails when part count does not match',
      makePhases({
        'expectedPartCounts': {'web/main.dart.js': 1}
      }),
      {
    'a|web/main.dart.js': '',
    'a|web/main.dart.js_1.part.js': '',
    'a|web/main.dart.js_2.part.js': ''
  },
      {},
      [
    'error: Found 2 part files, but expected 1 !!!'
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

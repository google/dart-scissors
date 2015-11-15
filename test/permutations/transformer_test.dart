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
library scissors.test.permutations.transformer_test;

import 'package:barback/barback.dart'
    show BarbackMode, BarbackSettings, Transformer;
import 'package:code_transformers/tests.dart'
    show StringFormatter, applyTransformers;
import 'package:test/test.dart' show test;
import 'package:scissors/src/permutations/transformer.dart';

makePhases(Map config) => [
      [
        new PermutationsTransformer.asPlugin(
            new BarbackSettings(config, BarbackMode.RELEASE))
      ]
    ];

void main() {
  var phases = makePhases({});

  _testPhases(
      'Concatenates deferred messages in pre-loaded permutations', phases, {
    'a|main.deferred_map': r'''
      {
        "_comment": "This mapping shows which compiled `.js` files are needed for a given deferred library import.",
        "package:a/messages_all.dart": {
          "name": "messages_all",
          "imports": {
            "messages_ar": [
              "main.dart.js_2.part.js"
            ],
            "messages_bg": [
              "main.dart.js_1.part.js"
            ]
          }
        }
      }
    ''',
    'a|main.dart.js': 'content of main.dart.js',
    'a|main.dart.js_1.part.js': 'content of main.dart.js_1.part.js',
    'a|main.dart.js_2.part.js': 'content of main.dart.js_2.part.js',
  }, {
    'a|main_ar.js': 'content of main.dart.js\n'
        'content of main.dart.js_2.part.js',
    'a|main_bg.js': 'content of main.dart.js\n'
        'content of main.dart.js_1.part.js',
  });
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

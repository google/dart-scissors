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

import 'package:barback/barback.dart' show BarbackMode, BarbackSettings;
import 'package:scissors/src/permutations/transformer.dart';

import 'package:transformer_test/utils.dart' show testPhases;
import 'package:test/test.dart';

List<List> makePhases(Map config) => <List>[
      [
        new PermutationsTransformer.asPlugin(
            new BarbackSettings(config, BarbackMode.RELEASE))
      ]
    ];

void main() {
  group('PermutationsTransformer', () {
    var deferredMap = r'''
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
            ],
            "tc_ltr": [
              "main.dart.js_100.part.js"
            ],
            "tc_rtl": [
              "main.dart.js_200.part.js"
            ]
          }
        }
      }
    ''';

    testPhases('Concatenates deferred messages in pre-loaded permutations',
        makePhases({}), {
      'a|main.deferred_map': deferredMap,
      'a|main.dart.js': 'content of main.dart.js\n'
          '//# sourceMappingURL=main.map',
      'a|main.dart.js_1.part.js': 'content of main.dart.js_1.part.js\n'
          '//# sourceMappingURL=part1.map',
      'a|main.dart.js_2.part.js': 'content of main.dart.js_2.part.js\n'
          '//# sourceMappingURL=part1.map',
      'a|main.dart.js.map': 'map of main.dart.js',
      'a|main.dart.js_1.part.js.map': 'map of main.dart.js_1.part.js',
      'a|main.dart.js_2.part.js.map': 'map of main.dart.js_2.part.js',
    }, {
      'a|main_ar.js': 'content of main.dart.js\n'
          'content of main.dart.js_2.part.js\n'
          '//# sourceMappingURL=main_ar.js.map',
      'a|main_bg.js': 'content of main.dart.js\n'
          'content of main.dart.js_1.part.js\n'
          '//# sourceMappingURL=main_bg.js.map',
      'a|main_en_US.js': 'content of main.dart.js\n'
          '//# sourceMappingURL=main_en_US.js.map',
      // TODO(ochafik): Compose maps of parts (just merge symbols + add offsets,
      // using package:source_map).
      'a|main_ar.js.map': 'map of main.dart.js',
      'a|main_bg.js.map': 'map of main.dart.js',
      'a|main_en_US.js.map': 'map of main.dart.js'
    });

    testPhases(
        'Concatenates deferred messages and ltr / rtl imports in permutations',
        makePhases({
          "ltrImport": "tc_ltr",
          "rtlImport": "tc_rtl",
          "defaultLocale": "fr_CA"
        }),
        {
          'a|main.deferred_map': deferredMap,
          'a|main.dart.js': 'content of main.dart.js',
          'a|main.dart.js_1.part.js': 'content of main.dart.js_1.part.js',
          'a|main.dart.js_2.part.js': 'content of main.dart.js_2.part.js',
          'a|main.dart.js_100.part.js': 'content of LTR template cache',
          'a|main.dart.js_200.part.js': 'content of RTL template cache',
        },
        {
          'a|main_ar.js': 'content of main.dart.js\n'
              'content of main.dart.js_2.part.js\n'
              'content of RTL template cache',
          'a|main_bg.js': 'content of main.dart.js\n'
              'content of main.dart.js_1.part.js\n'
              'content of LTR template cache',
          'a|main_fr_CA.js': 'content of main.dart.js\n'
              'content of LTR template cache',
        });
  });
}

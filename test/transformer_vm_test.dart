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
library scissors.test;

import 'package:barback/barback.dart';
import 'package:code_transformers/tests.dart';
import 'package:scissors/transformer.dart';
import 'package:unittest/compact_vm_config.dart';

final phases = [
  [
    new ScissorsTransformer.asPlugin(
        new BarbackSettings({}, BarbackMode.RELEASE))
  ]
];

void main() {
  useCompactVMConfiguration();

  testPhases('does basic class and element selector pruning', phases, {
    'a|foo.css': r'''
      .used-class {}
      .unused-class {}
      absent-element {}
      present-element {}
    ''',
    'a|foo.html': r'''
      <present-element class="used-class inexistent-class">
      </present-element>
    ''',
  }, {
    'a|foo.css': r'''
      .used-class {}
      present-element {}
    '''
  });

  testPhases('only prunes css which html it could resolve', phases, {
    'a|foo.css': r'.some-class {}',
    'a|bar.css': r'.some-class {}',
    'a|baz.scss.css': r'.some-class {}',
    'a|foo.html': r'<div></div>',
    'a|baz.html': r'<div></div>',
  }, {
    'a|foo.css': r'',
    'a|bar.css': r'.some-class {}',
    'a|baz.scss.css': r'',
  });

  testPhases('supports descending and attribute selectors', phases, {
    'a|foo.css': r'''
      html body input[type="submit"] {}
      html body input[type="checkbox"] {}
    ''',
    'a|foo.html': r'''
      <input type="submit">
    ''',
  }, {
    'a|foo.css': r'''
      html body input[type="submit"] {}
    ''',
  });

  testPhases('processes class attributes with mustaches', phases, {
    'a|foo.css': r'''
      .what_1 {}
      .what-2 {}
      .what-3 {}
      .pre1-mid-suff1 {}
      .pre1--suff1 {}
      .pre1-suff_ {}
      .pre_-suff1 {}
      .pre2-suff_ {}
      .pre_-suff2 {}
    ''',
    'a|foo.html': r'''
      <div class="what_1 pre1-{{whatever}}-suff1 pre2{{...}}
                  {{...}}suff2 what-3"></div>
    ''',
  }, {
    'a|foo.css': r'''
      .what_1 {}
      .what-3 {}
      .pre1-mid-suff1 {}
      .pre1--suff1 {}
      .pre2-suff_ {}
      .pre_-suff2 {}
    ''',
  });

  testPhases('uses constant class names from ng-class', phases, {
    'a|foo.css': r'''
      .used-class {}
      .unused-class {}
      absent-element {}
      present-element {}
    ''',
    'a|foo.html': r'''
      <present-element ng-class="{
        'used-class': ifOnly,
        'inexistent-class': notAChance
      }">
      </present-element>
    ''',
  }, {
    'a|foo.css': r'''
      .used-class {}
      present-element {}
    '''
  });

  final htmlBodyDiv = r'''
      html{font-family:sans-serif}
      body{font-family:sans-serif}
      div{font-family:sans-serif}
    ''';
  testPhases('deals with synthetic html and body', phases, {
    'a|html.css': htmlBodyDiv,
    'a|html.html': r'<html></html>',
    'a|body.css': htmlBodyDiv,
    'a|body.html': r'<body></body>',
    'a|div.css': htmlBodyDiv,
    'a|div.html': r'<div></div>',
  }, {
    'a|html.css': r'''
      html{font-family:sans-serif}
      body{font-family:sans-serif}
    ''',
    'a|body.css': r'''
      body{font-family:sans-serif}
    ''',
    'a|div.css': r'''
      div{font-family:sans-serif}
    '''
  });
}

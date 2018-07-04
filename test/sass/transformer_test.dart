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

import 'package:barback/barback.dart'
    show AggregateTransformer, BarbackMode, BarbackSettings;
import 'package:scissors/src/sass/transformer.dart';
import 'package:scissors/src/utils/lazy_transformer_utils.dart';
import 'package:transformer_test/utils.dart' show testPhases;

List<List> makePhases(Map config) => <List>[
      [
        new EagerTransformerWrapper<AggregateTransformer>(
            new SassCTransformer.asPlugin(
                new BarbackSettings(config, BarbackMode.RELEASE)))
      ]
    ];

void main() {
  var phases = makePhases({});

  testPhases('runs sassc on .scss and .sass inputs', phases, {
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
        //'\t"sourcesContent": [],\n'
        '\t"mappings": "AAAM,IAAI,AAAC,CACH,KAAK,CAAE,IAAK,CACb",\n'
        '\t"names": []\n'
        '}',
    'a|foo.sass.css': '.foo{height:100%}\n',
    'a|foo.sass.css.map': '{\n'
        '\t"version": 3,\n'
        '\t"file": "foo.sass.css",\n'
        '\t"sources": [\n'
        '\t\t"foo.sass"\n'
        '\t],\n'
        // '\t"sourcesContent": [],\n'
        '\t"mappings": "AAAA,IAAI,AAAC,CACH,MAAM,CAAE,IAAK,CAAG",\n'
        '\t"names": []\n'
        '}'
  });

  testPhases(
      'does not confuse same-named assets from different packages', phases, {
    'a|foo.scss': '''
      .foo {
        float: left;
      }
    ''',
    'b|foo.scss': '''
      .foo {
        float: right;
      }
    ''',
  }, {
    'a|foo.scss.css': '.foo{float:left}\n',
    'b|foo.scss.css': '.foo{float:right}\n',
  });

  // testPhases('does not run sassc on .scss that are already converted', phases, {
  //   'a|foo.scss': '''
  //     .foo {
  //       float: left;
  //     }
  //   ''',
  //   'a|foo.scss.css': '/* do not modify */'
  // }, {
  //   'a|foo.scss.css': '/* do not modify */'
  // });

  testPhases('reports sassc errors properly', phases, {
    'a|foo.scss': '''
      .foo {{
        float: left;
      }
    '''
  }, {}, messages: [
    'error: Invalid CSS after "      .foo {": expected "}", was "{" (a%7Cfoo.scss 1 12)'
  ]);
}

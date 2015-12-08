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
library scissors.test.css_pruning.transformer_test;

import 'package:barback/barback.dart'
    show BarbackMode, BarbackSettings, Transformer;
import 'package:scissors/src/css_mirroring/transformer.dart';

import '../src/transformer_test_utils.dart';

makePhases(Map config) => [
  [
    new CssMirroringTransformer.asPlugin(
        new BarbackSettings(config, BarbackMode.RELEASE))
  ]
];

void main() {
  var phases = makePhases({});

  testPhases('removes empty rules', phases, {
    'a|foo2_unmatched_css_url.css': r'''
        .used-class {}
        .unused-class {}
    '''
  }, {
    'a|foo2_unmatched_css_url.css': r'''


    '''
  });

  testPhases(
      'changes rules contaning only direction dependent declarations to direction dependent rules without any rule for common values',
      phases, {
    'a|foo2_unmatched_css_url.css': r'''
          absent-element {
            float: left;
            margin-left: 100px;
        }
          .usedclass {
            float: right;
            margin-right: 100px;
        }
        '''
  }, {
    'a|foo2_unmatched_css_url.css': r'''

          :host-context([dir="ltr"]) absent-element {
            float: left;
            margin-left: 100px;
        }
          :host-context([dir="ltr"]) .usedclass {
            float: right;
            margin-right: 100px;
        }

          :host-context([dir="rtl"]) absent-element {
            float: right;
            margin-right: 100px;
        }
          :host-context([dir="rtl"]) .usedclass {
            float: left;
            margin-left: 100px;
        }
        '''
  });
  testPhases('keeps the rule with no changing declaration as same', phases, {
    'a|foo2_unmatched_css_url.css': r'''
          absent-element {
            color: blue;
        }
          .usedclass {
            background-size: 16px 16px;
        }
        '''
  }, {
    'a|foo2_unmatched_css_url.css': r'''
          absent-element {
            color: blue;
        }
          .usedclass {
            background-size: 16px 16px;
        }
        '''
  });
  testPhases(
      'splits the rule with language dependent declaration to common rule and language dependent rules',
      phases, {
    'a|foo2_unmatched_css_url.css': r'''
          absent-element {
            color: blue;
            float: right;
        }
          .usedclass {
            background-size: 16px 16px;
        }
       '''
  }, {
    'a|foo2_unmatched_css_url.css': r'''
          absent-element {
            color: blue;
            }
          .usedclass {
            background-size: 16px 16px;
        }

          :host-context([dir="ltr"]) absent-element {
            float: right;
        }

          :host-context([dir="rtl"]) absent-element {
            float: left;
        }
        '''
  });

  testPhases(
      'splits the exotic rules with language dependent declaration to common rule and language dependent rules',
      phases, {
    'a|foo2_unmatched_css_url.css': r'''
        li + li {
        color: blue;
        float: right;
        }
        a ~ a {
          color: purple;
          margin-left: 3em;
        }
        '''
  }, {
    'a|foo2_unmatched_css_url.css': r'''
        li + li {
        color: blue;
        }
        a ~ a {
          color: purple;
          }

        :host-context([dir="ltr"]) li + li {
        float: right;
        }
        :host-context([dir="ltr"]) a ~ a {
          margin-left: 3em;
        }

        :host-context([dir="rtl"]) li + li {
        float: left;
        }
        :host-context([dir="rtl"]) a ~ a {
          margin-right: 3em;
        }
        '''
  });
}

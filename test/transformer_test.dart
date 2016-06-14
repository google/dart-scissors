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

import 'package:barback/barback.dart' show BarbackMode, BarbackSettings;
import 'package:scissors/eager_transformer.dart';

import 'package:transformer_test/utils.dart' show testPhases;

List<List> makePhases(Map config) => new EagerScissorsTransformerGroup.asPlugin(
        new BarbackSettings(config, BarbackMode.RELEASE))
    .phases;

void main() {
  var phases = makePhases({'pruneCss': true});

  var iconSvg = r'''
    <?xml version="1.0" encoding="utf-8"?>
    <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
      <rect x="0" y="0" height="10" width="10" style="stroke:#00ff00; fill: #ff0000"/>
    </svg>
  ''';
  var iconSvgData =
      'PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPjxyZWN0IHg9IjAiIHk9IjAiIGhlaWdodD0iMTAiIHdpZHRoPSIxMCIgc3R5bGU9InN0cm9rZTojMDBmZjAwO2ZpbGw6I2ZmMDAwMCIvPjwvc3ZnPg==';

  testPhases('inlines inlined images when inlineInlinedImages is set', phases, {
    'a|foo.sass': '''
.unused-class
  foo: 0;
div
  background-image: inline-image('icon.svg');
    ''',
    'a|icon.svg': iconSvg,
    'a|foo.html': r'<div></div>',
  }, {
    'a|foo.sass.css':
        '''div{background-image:url('data:image/svg+xml;base64,$iconSvgData')}\n'''
  });
}

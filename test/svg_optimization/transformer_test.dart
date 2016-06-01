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
library scissors.test.svg_optimization.transformer_test;

import 'package:barback/barback.dart' show BarbackMode, BarbackSettings;
import 'package:scissors/src/svg_optimization/transformer.dart';

import 'package:transformer_test/utils.dart' show testPhases;

List<List> makePhases(Map config) => <List>[
      [
        new SvgOptimizationTransformer.asPlugin(
            new BarbackSettings(config, BarbackMode.RELEASE))
      ]
    ];

void main() {
  testPhases('trims SVG files', makePhases({}), {
    'a|foo.svg': r'''
      <?xml version="1.0" encoding="utf-8"?>
      <!-- Generator: Adobe Illustrator 15.0.0, SVG Export Plug-In  -->
      <!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd" [
        <!ENTITY ns_flows "http://ns.adobe.com/Flows/1.0/">
      ]>
      <svg version="1.1"
         xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:a="http://ns.adobe.com/AdobeSVGViewerExtensions/3.0/"
         x="0px" y="0px" width="21px" height="21px" viewBox="0 0 21 21" overflow="visible" enable-background="new 0 0 21 21"
         xml:space="preserve">
        <defs>
        </defs>
        <!-- And this is...
             ... a multiline comment! -->
        <rect x="0" y="0" height="10" width="10" style="stroke:#00ff00; fill: #ff0000"/>
      </svg>
    '''
  }, {
    'a|foo.svg': '<svg version="1.1" xmlns="http://www.w3.org/2000/svg" '
        'x="0px" y="0px" width="21px" height="21px" viewBox="0 0 21 21" '
        'overflow="visible" enable-background="new 0 0 21 21">'
        '<rect x="0" y="0" height="10" width="10" style="stroke:#00ff00;fill:#ff0000"/>'
        '</svg>'
  });
}

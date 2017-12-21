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
library scissors.test.image_inlining.transformer_test;

import 'package:barback/barback.dart' show BarbackMode, BarbackSettings;
import 'package:scissors/src/utils/enum_parser.dart';
import 'package:scissors/src/image_inlining/transformer.dart';

import 'package:transformer_test/utils.dart' show testPhases;

List<List> makePhases(Map config) => <List>[
      [
        new ImageInliningTransformer.asPlugin(
            new BarbackSettings(config, BarbackMode.RELEASE))
      ]
    ];

void main() {
  List<List> phases(ImageInliningMode mode) =>
      makePhases({'imageInlining': enumName(mode)});

  var iconSvg = r'''
    <?xml version="1.0" encoding="utf-8"?>
    <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
      <rect x="0" y="0" height="10" width="10" style="stroke:#00ff00; fill: #ff0000"/>
    </svg>
  ''';
  var iconSvgData =
      'ICAgIDw/eG1sIHZlcnNpb249IjEuMCIgZW5jb2Rpbmc9InV0Zi04Ij8+CiAgICA8c3ZnIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiPgogICAgICA8cmVjdCB4PSIwIiB5PSIwIiBoZWlnaHQ9IjEwIiB3aWR0aD0iMTAiIHN0eWxlPSJzdHJva2U6IzAwZmYwMDsgZmlsbDogI2ZmMDAwMCIvPgogICAgPC9zdmc+CiAg';

  testPhases('inlines inlined images when inlineInlinedImages is set',
      phases(ImageInliningMode.inlineInlinedImages), {
    'a|foo.css': r'''
      div {
        background-image: inline-image('icon.svg');
        other-image: url('no-inline.svg');
      }
    ''',
    'a|icon.svg': iconSvg,
    'a|foo.html': r'<div></div>',
  }, {
    'a|foo.css': '''
      div {
        background-image: url('data:image/svg+xml;base64,$iconSvgData');
        other-image: url('no-inline.svg');
      }
    '''
  });

  testPhases('inlines all images when inlineAll is set',
      phases(ImageInliningMode.inlineAllUrls), {
    'a|foo.css': r'''
      div {
        foo: bar;
        some-image: url('icon.svg');
        baz: bam;
      }
    ''',
    'a|icon.svg': iconSvg,
    'a|foo.html': r'<div></div>',
  }, {
    'a|foo.css': '''
      div {
        foo: bar;
        some-image: url('data:image/svg+xml;base64,$iconSvgData');
        baz: bam;
      }
    '''
  });

  testPhases('just links to images noInline is set',
      phases(ImageInliningMode.linkInlinedImages), {
    'a|foo.css': r'''
      div {
        background-image: inline-image('no-inline.svg');
        other-image: url('no-inline-either.svg');
      }
    ''',
    'a|no-inline.svg': 'no inline',
    'a|no-inline-either.svg': 'no inline either',
    'a|icon.svg': iconSvg,
    'a|foo.html': r'<div></div>',
  }, {
    'a|foo.css': r'''
      div {
        background-image: url('packages/a/no-inline.svg');
        other-image: url('no-inline-either.svg');
      }
    '''
  });

  testPhases(
      'does nothing with disablePass', phases(ImageInliningMode.disablePass), {
    'a|foo.css': r'''
      div {
        background-image: inline-image('inlined-image.svg');
        other-image: url('linked-image.svg');
      }
    ''',
    'a|icon.svg': iconSvg,
    'a|foo.html': r'<div></div>',
  }, {
    'a|foo.css': r'''
      div {
        background-image: inline-image('inlined-image.svg');
        other-image: url('linked-image.svg');
      }
    '''
  });

  testPhases('does not confuse same-named images from different packages',
      phases(ImageInliningMode.inlineInlinedImages), {
    'a|foo.css': r'''
      div {
        background-image: inline-image('icona.svg');
      }
    ''',
    'b|foo.css': r'''
      div {
        other-image: inline-image('iconb.svg');
      }
    ''',
    'a|icona.svg': iconSvg,
    'b|iconb.svg': iconSvg,
  }, {
    'a|foo.css': '''
      div {
        background-image: url('data:image/svg+xml;base64,$iconSvgData');
      }
    ''',
    'b|foo.css': '''
      div {
        other-image: url('data:image/svg+xml;base64,$iconSvgData');
      }
    '''
  });

  testPhases('deals with /deep/ selectors in skippable files',
      phases(ImageInliningMode.inlineInlinedImages), {
    'a|foo.css': '''
      :host /deep/ {
        float: left;
        background-image: url('inlined-image.svg');
      }
    ''',
  }, {
    'a|foo.css': '''
      :host /deep/ {
        float: left;
        background-image: url('inlined-image.svg');
      }
    '''
  },
      messages: []);

  testPhases('deals with /deep/ selectors in inlined files',
      phases(ImageInliningMode.inlineInlinedImages), {
    'a|foo.css': '''
      :host /deep/ {
        float: left;
        background-image: inline-image('icon.svg');
      }
    ''',
    'a|icon.svg': iconSvg,
  }, {
    'a|foo.css': '''
      :host /deep/ {
        float: left;
        background-image: url('data:image/svg+xml;base64,$iconSvgData');
      }
    '''
  },
      messages: []);
}

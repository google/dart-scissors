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

import 'package:barback/barback.dart' show BarbackMode, BarbackSettings;
import 'package:scissors/src/sourcemap_stripping/transformer.dart';

import 'package:transformer_test/utils.dart' show testPhases;

List<List> makePhases(Map config) => <List>[
      [
        new SourcemapStrippingTransformer.asPlugin(
            new BarbackSettings(config, BarbackMode.RELEASE))
      ]
    ];

void main() {
  var src = r'''
    blah
    //# sourceMappingURL=foo.dart.js.map
  ''';
  var strippedSrc = r'''
    blah

  ''';

  testPhases('strips sourcemaps by default', makePhases({}),
      {'a|foo.dart.js': src}, {'a|foo.dart.js': strippedSrc});

  testPhases(
      'does not strip sourcemaps when told not to',
      makePhases({'stripSourceMaps': false}),
      {'a|foo.dart.js': src},
      {'a|foo.dart.js': src});
}

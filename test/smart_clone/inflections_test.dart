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

import 'package:test/test.dart';
import 'package:scissors/src/smart_clone/inflections.dart';

main() {
  group('English inflections for', () {
    List<String> inflections(String word) =>
        English.inflections.map((i) => i(word)).toSet().toList();

    test('simple text', () {
      expect(inflections('Reset'), ['Reset', 'Resettes', 'Resets', 'Resetter', 'Resetted', 'Resetting']);
      expect(inflections('Test'), ['Test', 'Tests', 'Tester', 'Tested', 'Testing']);
      expect(inflections('Bar'), ['Bar', 'Barres', 'Bars', 'Barrer', 'Barred', 'Barring']);
    });
    test('inflections', () {
      expect(inflections('Proxy'), ['Proxy', 'Proxies', 'Proxier', 'Proxied', 'Proxying']);
      expect(inflections('Sky'), ['Sky', 'Skies', 'Skier', 'Skied', 'Skiing']);
      expect(inflections('Leaf'), ['Leaf', 'Leaffes', 'leaves', 'Leaffer', 'Leaffed', 'Leaffing']);
      expect(inflections('Vertex'), ['Vertex', 'Vertices', 'Vertexer', 'Vertexed', 'Vertexing']);
    });
  });
}

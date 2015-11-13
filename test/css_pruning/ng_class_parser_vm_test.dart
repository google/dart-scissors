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
library scissors.ng_class_parser.test;

import 'package:scissors/src/css_pruning/ng_class_parser.dart';
import "package:test/test.dart";

main() {
  group('NgClassParsingResults', () {
    test('checks its constructor params', () {
      expect(() => new NgClassParsingResults(true, null), throws);
      expect(() => new NgClassParsingResults(null, []), throws);
    });

    var distinctFactories = [
      () => new NgClassParsingResults(true, []),
      () => new NgClassParsingResults(false, []),
      () => new NgClassParsingResults(true, ["a"]),
      () => new NgClassParsingResults(false, ["b"]),
    ];

    test('has valid hashCode', () {
      for (var factory in distinctFactories) {
        expect(factory().hashCode, factory().hashCode);
      }
    });

    test('has valid operator==', () {
      var distinct = distinctFactories.map((factory) => factory());
      expect((new Set()..addAll(distinct)..addAll(distinct)).length,
          distinct.length);
    });
  });

  group('parseNgClassAttribute', () {
    test('rejects unsupported or invalid syntaxes', () {
      expect(parseNgClassAttribute(""), null);
      expect(parseNgClassAttribute("foo"), null);
      expect(parseNgClassAttribute("[]"), null);
      expect(parseNgClassAttribute("{"), null);
      expect(parseNgClassAttribute("}"), null);
      expect(parseNgClassAttribute("{a + b: c}"), null);
    });

    test('handle simple map syntaxes', () {
      expect(parseNgClassAttribute("{}"), new NgClassParsingResults(false, []));
      expect(parseNgClassAttribute("{'a': b, 'c': d}"),
          new NgClassParsingResults(false, ['a', 'c']));
      expect(parseNgClassAttribute("{a: b + c * d.e.f, 'g': h}"),
          new NgClassParsingResults(true, ['g']));
    });
  });
}

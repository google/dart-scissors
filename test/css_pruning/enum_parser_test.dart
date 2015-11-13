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
library scissors.src.enum_parser;

import 'package:scissors/src/utils/enum_parser.dart';
import 'package:test/test.dart';

enum TestEnum { foo, bar }

main() {
  group('EnumParser', () {
    var parser;
    setUp(() {
      parser = new EnumParser<TestEnum>(TestEnum.values);
    });
    test('parses known enum values', () {
      expect(parser.parse('foo'), TestEnum.foo);
      expect(parser.parse('bar'), TestEnum.bar);
    });
    test('throws when given unknown values', () {
      expect(() => parser.parse('baz'), throws);
    });
  });
}

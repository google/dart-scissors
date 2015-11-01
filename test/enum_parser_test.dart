library scissors.src.enum_parser;

import 'package:scissors/src/enum_parser.dart';
import 'package:test/test.dart';

enum TestEnum {
  foo,
  bar
}

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

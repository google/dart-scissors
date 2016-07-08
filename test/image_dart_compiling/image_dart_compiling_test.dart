library scissors.test.image_inlining.image_dart_compiling_test;

import 'package:test/test.dart';
import 'package:scissors/src/image_dart_compiling/image_dart_compiling.dart';

main() {
  group('identifierFromFileName', () {
    test('prepends prefix when needed', () {
      expect(identifierFromFileName("10-test-image.png"),
          equals("img_10_test_image"));
    });

    test('does not prepend prefix when not needed', () {
      expect(identifierFromFileName("icon.svg"), equals("icon"));
    });

    test('prepends prefix when file name starts with an underscore', () {
      expect(identifierFromFileName("_icon.svg"), equals("img__icon"));
    });
  });
}

library scissors.src.css_mirroring.bidi_css_generator;

import 'package:unittest/unittest.dart';
import 'package:csslib/parser.dart' show parse;
import 'package:csslib/visitor.dart'
    show TreeNode, DeclarationGroup, Declaration, RuleSet;
import 'package:scissors/src/css_mirroring/entity.dart';

main() {
  List<Declaration> _parseDeclarations(String decls) =>
      (parse('.foo $decls ').topLevels.single as RuleSet)
          .declarationGroup
          .declarations;

  test('getDeclarationEnd finds a corresponding end', () {
    String inputCss =
        '{color: blue;float: left /* because `foo: right;` will also work */; /* Test comment { } */}';
    expect(getDeclarationEnd(inputCss, _parseDeclarations(inputCss), 1),
        equals(inputCss.length - 1));
  });

  test('getDeclarationEnd throws error when it doesnot find a closing bracket',
      () {
    var inputCss =
        '{color: blue;float: left /* because `foo: right;` will also work */; /* Test comment { } */';
    try {
      getDeclarationEnd(inputCss, _parseDeclarations(inputCss), 1);
    } catch (e) {
      expect(e.message, 'Declaration end not found');
    }
  });
}

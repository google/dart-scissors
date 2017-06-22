import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart' show RecursiveAstVisitor;
import 'package:analyzer/dart/element/element.dart';

class _EscapingLocalMutationsVisitor extends RecursiveAstVisitor {
  final localsMutatedInEscapingExecutableElements = new Set<LocalElement>();

  static Element _getDeclarationElement(AstNode node) => node is Declaration
      ? node.element
      : node is FunctionExpression ? node.element : null;
  static bool _isExecutable(AstNode node) =>
      _getDeclarationElement(node) is ExecutableElement;

  static bool _isIdentifierReferencedWithinADifferentExecutable(
      SimpleIdentifier node, LocalElement local) {
    assert(node.bestElement == local);
    final enclosingExecutable = node.getAncestor(_isExecutable);
    return _getDeclarationElement(enclosingExecutable) !=
        local.enclosingElement;
  }

  _handleAssignmentTarget(Expression target) {
    if (target is SimpleIdentifier) {
      final local = getLocalVar(target);
      if (local != null &&
          !localsMutatedInEscapingExecutableElements.contains(local) &&
          _isIdentifierReferencedWithinADifferentExecutable(target, local)) {
        localsMutatedInEscapingExecutableElements.add(local);
      }
    }
  }

  @override
  visitAssignmentExpression(AssignmentExpression node) {
    node.visitChildren(this);
    _handleAssignmentTarget(node.leftHandSide);
    return null;
  }
}

LocalElement getLocalVar(Expression expr) {
  if (expr is SimpleIdentifier) {
    var element = expr.bestElement;
    if (element is LocalVariableElement || element is ParameterElement) {
      return element;
    }
  }
  return null;
}

Set<LocalElement> findLocalsMutatedInEscapingExecutableElements(AstNode node) {
  final visitor = new _EscapingLocalMutationsVisitor();
  node.accept(visitor);
  return visitor.localsMutatedInEscapingExecutableElements;
}

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart' show RecursiveAstVisitor;
import 'package:analyzer/dart/element/element.dart';

import 'knowledge.dart';

class _EscapingLocalMutationsVisitor extends RecursiveAstVisitor {
  final localsMutatedInEscapingExecutableElements = new Set<LocalElement>();
  final ExpressionPredicate isNullable;
  _EscapingLocalMutationsVisitor(this.isNullable);

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

  @override
  visitAssignmentExpression(AssignmentExpression node) {
    node.visitChildren(this);

    final target = node.leftHandSide;
    if (target is SimpleIdentifier) {
      final value = node.rightHandSide;
      if (!isNullable(value)) {
        return null;
      }

      final local = getLocalVar(target);
      if (local != null &&
          !localsMutatedInEscapingExecutableElements.contains(local) &&
          _isIdentifierReferencedWithinADifferentExecutable(target, local)) {
        localsMutatedInEscapingExecutableElements.add(local);
      }
    }
    return null;
  }
}

class _LocalMutationsVisitor extends RecursiveAstVisitor {
  final localsMutated = new Set<LocalElement>();
  final ExpressionPredicate isNullable;
  _LocalMutationsVisitor(this.isNullable);

  _handleAssignmentTarget(Expression target) {
    if (target is SimpleIdentifier) {
      final local = getLocalVar(target);
      if (local != null) localsMutated.add(local);
    }
  }

  @override
  visitAssignmentExpression(AssignmentExpression node) {
    node.visitChildren(this);
    _handleAssignmentTarget(node.leftHandSide);
    return null;
  }
}

bool isLocalElement(Element element) =>
    element is LocalVariableElement || element is ParameterElement;

LocalElement getLocalVar(Expression expr) {
  if (expr is SimpleIdentifier) {
    var element = expr.bestElement;
    if (isLocalElement(element)) return element;
  }
  return null;
}

Set<LocalElement> findLocalsMutatedInEscapingExecutableElements(
    AstNode node,
    ExpressionPredicate isNullable) {
  final visitor = new _EscapingLocalMutationsVisitor(isNullable);
  node.accept(visitor);
  return visitor.localsMutatedInEscapingExecutableElements;
}

Set<LocalElement> findLocalsMutated(
    AstNode node,
    ExpressionPredicate isNullable) {
  final visitor = new _LocalMutationsVisitor(isNullable);
  node.accept(visitor);
  return visitor.localsMutated;
}

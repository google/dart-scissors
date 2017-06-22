// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 *
 * - 1st pass with escape analysis to detect variables to skip
 * - loops: need to merge arcs from before and *after* the loop
 *   - easy fix: eliminate knowledge about variables potentially assigned vars inside the loop from both the loop context and the after context.
 * - other caveats:
 *   - fallthrough switches
 *   - labelled breaks
 *   - exception handlers
 * - TODO(ochafik): ask about benchmarks
 * - generic data-flow analyzer?
 *
 * - gclient sync
 * - ./tools/pie/mrelease # build sdk
 * - cd pkg/dev_compiler
 * - ./tools/presubmit.sh
 */

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart' show Token, TokenType;
import 'package:analyzer/dart/ast/visitor.dart' show RecursiveAstVisitor;
import 'package:analyzer/dart/element/element.dart';
import 'package:scissors/src/nullability/implications.dart';
import 'package:scissors/src/nullability/knowledge.dart';

// const logVisits = true;
const logVisits = false;

LocalElement _getLocalVar(Expression expr) {
  if (expr is SimpleIdentifier) {
    var element = expr.bestElement;
    if (element is LocalVariableElement || element is ParameterElement) {
      return element;
    }
  }
  return null;
}

class FlowAwareNullableLocalInference
    extends RecursiveAstVisitor<Implications> {
  final results = <LocalElement, Map<SimpleIdentifier, Knowledge>>{};
  final _stacks = <LocalElement, List<Knowledge>>{};

  Knowledge getKnowledge(LocalElement variable) {
    if (variable == null) return null;

    final stack = _stacks[variable];
    return stack == null || stack.isEmpty ? null : stack.last;
  }

  R _withKnowledge<R>(Map<LocalElement, Knowledge> knowledge, R f()) {
    knowledge?.forEach((v, n) {
      _stacks.putIfAbsent(v, () => <Knowledge>[]).add(n);
    });
    try {
      return f();
    } finally {
      knowledge?.forEach((v, n) {
        _stacks[v].removeLast();
      });
    }
  }

  T _log<T>(String title, AstNode node, T f()) {
    if (logVisits) print('$title($node)');
    final result = f();
    if (logVisits && result != null) print('$title($node) -> $result');
    return result;
  }

  Implications _handleSequence(List<AstNode> sequence,
      {Implications andThen(Implications implications),
      Implications getCustomImplications(int index, AstNode item)}) {
    Implications aux(int index, Implications previousImplications) {
      if (index < sequence.length) {
        final item = sequence[index];
        final itemImplications = getCustomImplications == null
            ? item.accept(this)
            : getCustomImplications(index, item);
        // print("SEQUENCE: item = $item, implications: $itemImplications, previous: $previousImplications");
        if (itemImplications == null) {
          return aux(index + 1, previousImplications);
        } else {
          final implications =
              Implications.then(previousImplications, itemImplications);
          return _withKnowledge(itemImplications.getKnowledgeForNextOperation(),
              () {
            return aux(index + 1, implications);
          });
        }
      } else {
        return andThen == null
            ? previousImplications
            : andThen(previousImplications);
      }
    }

    return aux(0, null);
  }

  @override
  Implications visitAdjacentStrings(AdjacentStrings node) {
    return _log('visitAdjacentStrings', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitAnnotation(Annotation node) {
    return _log('visitAnnotation', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitArgumentList(ArgumentList node) {
    return _log('visitArgumentList', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitAsExpression(AsExpression node) {
    return _log('visitAsExpression', node, () {
      return node.expression.accept(this);
    });
  }

  @override
  Implications visitAssignmentExpression(AssignmentExpression node) {
    return _log('visitAssignmentExpression', node, () {
      final leftLocal = _getLocalVar(node.leftHandSide);
      final rightLocal = _getLocalVar(node.rightHandSide);
      final rightKnowledge = getKnowledge(rightLocal);

      final rightImplications = node.rightHandSide.accept(this);
      return _withKnowledge(rightImplications?.getKnowledgeForNextOperation(),
          () {
        final leftImplications = node.leftHandSide.accept(this);
        return Implications.then(
            rightImplications,
            Implications.union(
                new Implications(
                    {leftLocal: Implication.fromKnowledge(rightKnowledge)}),
                leftImplications));
      });
    });
  }

  @override
  Implications visitAwaitExpression(AwaitExpression node) {
    return _log('visitAwaitExpression', node, () {
      return node.expression.accept(this);
    });
  }

  @override
  Implications visitBinaryExpression(BinaryExpression node) {
    return _log('visitBinaryExpression', node, () {
      final leftLocal = _getLocalVar(node.leftOperand);
      final rightLocal = _getLocalVar(node.rightOperand);

      Implications handleNullComparison(
          Expression operand, LocalElement variable, Token operator) {
        final operandImplications = Implications.then(operand.accept(this));
        switch (operator.type) {
          case TokenType.EQ_EQ:
            return Implications.union(
                operandImplications,
                new Implications({
                  variable: Implication.isNullIfExpressionIsTrue |
                      Implication.isNotNullIfExpressionIsFalse
                }));
          case TokenType.BANG_EQ:
            return Implications.union(
                operandImplications,
                new Implications({
                  variable: Implication.isNotNullIfExpressionIsTrue |
                      Implication.isNullIfExpressionIsFalse
                }));
          default:
            return operandImplications;
        }
      }

      if (leftLocal != null && node.rightOperand is NullLiteral) {
        // node.visitChildren(this);
        return handleNullComparison(node.leftOperand, leftLocal, node.operator);
      } else if (rightLocal != null && node.leftOperand is NullLiteral) {
        // node.visitChildren(this);
        return handleNullComparison(
            node.rightOperand, rightLocal, node.operator);
      } else if (leftLocal != null && rightLocal != null) {
        node.visitChildren(this);
        if (node.operator.type == TokenType.EQ_EQ) {
          // TODO: Upon equality, transfer knowledge between left<->right
          // operands.
          // Also: should declare 1st is not exploding
          final leftKnowledge = getKnowledge(leftLocal);
          final rightKnowledge = getKnowledge(rightLocal);
          final data = <LocalElement, int>{};
          if (leftKnowledge != null) {
            data[rightLocal] =
                Implication.bindKnowledgeToBoolExpression(leftKnowledge, true);
          }
          if (rightKnowledge != null) {
            data[leftLocal] =
                Implication.bindKnowledgeToBoolExpression(rightKnowledge, true);
          }
          return new Implications(data);
          // final leftImplications = new Implications.hasKnowledge(leftVariable, rightKnowledge);
          // final rightImplications = new Implications.hasKnowledge(rightVariable, leftKnowledge);
          // return Implications.union(leftImplications, rightImplications);
        }
      } else {
        final leftImplications = node.leftOperand.accept(this);
        switch (node.operator.type) {
          case TokenType.AMPERSAND_AMPERSAND:
            return _withKnowledge(
                leftImplications.getKnowledgeForAndRightOperand(), () {
              return Implications.and(
                  leftImplications, node.rightOperand.accept(this));
            });
          case TokenType.BAR_BAR:
            return _withKnowledge(
                leftImplications.getKnowledgeForOrRightOperand(), () {
              return Implications.or(
                  leftImplications, node.rightOperand.accept(this));
            });
          // case TokenType.QUESTION_QUESTION:
        }
      }
      // node.visitChildren(this);
      return Implications.then(
          node.leftOperand.accept(this), node.rightOperand.accept(this));
    });
  }

  @override
  Implications visitBlock(Block node) {
    return _log('visitBlock', node, () {
      return _handleSequence(node.statements);
    });
  }

  @override
  Implications visitBreakStatement(BreakStatement node) {
    return _log('visitBreakStatement', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitCascadeExpression(CascadeExpression node) {
    return _log('visitCascadeExpression', node, () {
      // TODO: acknowledge that the target is not null after the first call,
      // e.g. `x..f()..g(/*not-null*/x)`
      final targetLocal = _getLocalVar(node.target);
      return _handleSequence(node.cascadeSections,
          getCustomImplications: (index, item) {
        final defaultImplications = item.accept(this);
        if (index == 0) {
          // final implications = Implications.then(previousImplications, itemImplications);
          return _withKnowledge(
              defaultImplications?.getKnowledgeForNextOperation(), () {
            var targetImplications = node.target.accept(this);
            if (targetLocal != null) {
              targetImplications = Implications.union(targetImplications,
                  new Implications({targetLocal: Implication.isNotNull}));
            }
            return Implications.then(defaultImplications, targetImplications);
          });
        } else {
          return defaultImplications;
        }
      });
    });
  }

  @override
  Implications visitCatchClause(CatchClause node) {
    return _log('visitCatchClause', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitContinueStatement(ContinueStatement node) {
    return _log('visitContinueStatement', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitDeclaredIdentifier(DeclaredIdentifier node) {
    return _log('visitDeclaredIdentifier', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitDefaultFormalParameter(DefaultFormalParameter node) {
    return _log('visitDefaultFormalParameter', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitDoStatement(DoStatement node) {
    return _log('visitDoStatement', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitExpressionStatement(ExpressionStatement node) {
    return _log('visitExpressionStatement', node, () {
      return node.expression.accept(this);
    });
  }

  @override
  Implications visitFieldFormalParameter(FieldFormalParameter node) {
    return _log('visitFieldFormalParameter', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitForEachStatement(ForEachStatement node) {
    return _log('visitForEachStatement', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitFormalParameterList(FormalParameterList node) {
    return _log('visitFormalParameterList', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitForStatement(ForStatement node) {
    return _log('visitForStatement', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitFunctionDeclaration(FunctionDeclaration node) {
    return _log('visitFunctionDeclaration', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitFunctionDeclarationStatement(
      FunctionDeclarationStatement node) {
    return _log('visitFunctionDeclarationStatement', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitFunctionExpression(FunctionExpression node) {
    return _log('visitFunctionExpression', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitFunctionExpressionInvocation(
      FunctionExpressionInvocation node) {
    return _log('visitFunctionExpressionInvocation', node, () {
      // f(x.a, x.b) -> f(dart.notNull(x).a, x.b)
      return _handleSequence(node.argumentList.arguments,
          andThen: (implications) {
        node.function.accept(this);
        final functionLocal = _getLocalVar(node.function);
        if (functionLocal != null) {
          return Implications.then(implications,
              new Implications({functionLocal: Implication.isNotNull}));
        } else {
          return implications;
        }
      });
    });
  }

  @override
  Implications visitIfStatement(IfStatement node) {
    return _log('visitIfStatement', node, () {
      final conditionImplications = node.condition.accept(this);
      final thenImplications = _withKnowledge(
          conditionImplications.getKnowledgeForAndRightOperand(), () {
        return node.thenStatement.accept(this);
      });
      if (node.elseStatement != null) {
        final elseImplications = _withKnowledge(
            conditionImplications.getKnowledgeForOrRightOperand(), () {
          return node.elseStatement.accept(this);
        });
        return Implications.then(conditionImplications,
            Implications.intersect(thenImplications, elseImplications));
      } else {
        return Implications.then(conditionImplications);
      }
    });
  }

  @override
  Implications visitConditionalExpression(ConditionalExpression node) {
    return _log('visitConditionalExpression', node, () {
      final conditionImplications = node.condition.accept(this);
      final thenImplications = _withKnowledge(
          conditionImplications.getKnowledgeForAndRightOperand(), () {
        return node.thenExpression.accept(this);
      });
      final elseImplications = _withKnowledge(
          conditionImplications.getKnowledgeForOrRightOperand(), () {
        return node.elseExpression.accept(this);
      });
      return Implications.union(
          Implications.then(conditionImplications),
          Implications.intersect(thenImplications, elseImplications));
    });
  }

  @override
  Implications visitImplementsClause(ImplementsClause node) {
    return _log('visitImplementsClause', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitImportDirective(ImportDirective node) {
    return _log('visitImportDirective', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitIndexExpression(IndexExpression node) {
    return _log('visitIndexExpression', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitInstanceCreationExpression(
      InstanceCreationExpression node) {
    return _log('visitInstanceCreationExpression', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitIntegerLiteral(IntegerLiteral node) {
    return _log('visitIntegerLiteral', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitInterpolationExpression(InterpolationExpression node) {
    return _log('visitInterpolationExpression', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitInterpolationString(InterpolationString node) {
    return _log('visitInterpolationString', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitIsExpression(IsExpression node) {
    return _log('visitIsExpression', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitLabel(Label node) {
    return _log('visitLabel', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitLabeledStatement(LabeledStatement node) {
    return _log('visitLabeledStatement', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitLibraryDirective(LibraryDirective node) {
    return _log('visitLibraryDirective', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitLibraryIdentifier(LibraryIdentifier node) {
    return _log('visitLibraryIdentifier', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitListLiteral(ListLiteral node) {
    return _log('visitListLiteral', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitMapLiteral(MapLiteral node) {
    return _log('visitMapLiteral', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitMapLiteralEntry(MapLiteralEntry node) {
    return _log('visitMapLiteralEntry', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitMethodDeclaration(MethodDeclaration node) {
    return _log('visitMethodDeclaration', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitMethodInvocation(MethodInvocation node) {
    return _log('visitMethodInvocation', node, () {
      // x.f(x.a, x.b) -> dart.notNull(x).f(dart.notNull(x).a, dart.notNull(x).b)
      // b != null && a == b && a.f();

      // x.f(x.a, x.b) -> x.f(dart.notNull(x).a, x.b)
      return _handleSequence(node.argumentList.arguments,
          andThen: (implications) {
        final targetLocal = node.realTarget == null
            ? _getLocalVar(node.methodName)
            : _getLocalVar(node.realTarget);
        node.target?.accept(this);
        node.methodName?.accept(this);
        if (targetLocal != null) {
          final localImplications =
              new Implications({targetLocal: Implication.isNotNull});
          return Implications.then(implications, localImplications);
        } else {
          return implications;
        }
      });
    });
  }

  @override
  Implications visitNamedExpression(NamedExpression node) {
    return _log('visitNamedExpression', node, () {
      return node.expression.accept(this);
    });
  }

  @override
  Implications visitNativeClause(NativeClause node) {
    return _log('visitNativeClause', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitNativeFunctionBody(NativeFunctionBody node) {
    return _log('visitNativeFunctionBody', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitNullLiteral(NullLiteral node) {
    return _log('visitNullLiteral', node, () {
      node.visitChildren(this);
      return null;
    });
  }

  @override
  Implications visitParenthesizedExpression(ParenthesizedExpression node) {
    return _log('visitParenthesizedExpression', node, () {
      return node.expression.accept(this);
    });
  }

  @override
  Implications visitPostfixExpression(PostfixExpression node) {
    return _log('visitPostfixExpression', node, () {
      node.visitChildren(this);
      // TODO
      return Implications.then(node.operand.accept(this));
    });
  }

  @override
  Implications visitPrefixedIdentifier(PrefixedIdentifier node) {
    return _log('visitPrefixedIdentifier', node, () {
      node.visitChildren(this);
      final targetLocal = _getLocalVar(node.prefix);
      if (targetLocal != null) {
        return new Implications({targetLocal: Implication.isNotNull});
      } else {
        return null;
      }
    });
  }

  @override
  Implications visitPropertyAccess(PropertyAccess node) {
    return _log('visitPropertyAccess', node, () {
      node.visitChildren(this);
      final targetLocal = _getLocalVar(node.target);
      if (targetLocal != null) {
        return new Implications({targetLocal: Implication.isNotNull});
      } else {
        return null;
      }
    });
  }

  @override
  Implications visitPrefixExpression(PrefixExpression node) {
    return _log('visitPrefixExpression', node, () {
      if (node.operator.type == TokenType.BANG) {
        return Implications.not(node.operand.accept(this));
      } else {
        return Implications.then(node.operand.accept(this));
      }
    });
  }

  @override
  Implications visitSimpleIdentifier(SimpleIdentifier node) {
    return _log('visitSimpleIdentifier', node, () {
      final local = _getLocalVar(node);
      if (local != null) {
        final knowledge = getKnowledge(local);
        // print('FOUND $local: $knowledge');
        if (knowledge != null) {
          results.putIfAbsent(
              local, () => <SimpleIdentifier, Knowledge>{})[node] = knowledge;
        }
      }
      return null;
    });
  }

  @override
  Implications visitSwitchCase(SwitchCase node) {
    return _log('visitSwitchCase', node, () {
      node.visitChildren(this);

      // TODO: switched expression is known not to be null inside.
      return null;
    });
  }

  @override
  Implications visitTryStatement(TryStatement node) {
    return _log('visitTryStatement', node, () {
      node.visitChildren(this);
      // TODO
      return null;
    });
  }

  @override
  Implications visitVariableDeclaration(VariableDeclaration node) {
    return _log('visitVariableDeclaration', node, () {
      node.visitChildren(this);
      // TODO: non-null assigments here?
      return null;
    });
  }

  @override
  Implications visitVariableDeclarationList(VariableDeclarationList node) {
    return _log('visitVariableDeclarationList', node, () {
      node.visitChildren(this);
      // TODO: sequence
      return null;
    });
  }

  @override
  Implications visitVariableDeclarationStatement(
      VariableDeclarationStatement node) {
    return _log('visitVariableDeclarationStatement', node, () {
      return node.variables.accept(this);
    });
  }

  @override
  Implications visitWhileStatement(WhileStatement node) {
    return _log('visitWhileStatement', node, () {
      node.visitChildren(this);
      // TODO: loop constraints + erase assigned variables in sequence
      return null;
    });
  }

  @override
  Implications visitWithClause(WithClause node) {
    return _log('visitWithClause', node, () {
      node.visitChildren(this);
      // TODO: ?
      return null;
    });
  }

  @override
  Implications visitYieldStatement(YieldStatement node) {
    return _log('visitYieldStatement', node, () {
      node.visitChildren(this);
      // TODO: ?
      return null;
    });
  }
}

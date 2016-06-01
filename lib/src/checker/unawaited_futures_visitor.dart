// Copyright 2016 Google Inc. All Rights Reserved.
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

import 'package:analyzer/analyzer.dart'
    show
        Expression,
        ExpressionStatement,
        AssignmentExpression,
        RecursiveAstVisitor,
        AstNode,
        InstanceCreationExpression,
        MethodInvocation,
        FunctionBody;
import 'package:analyzer/dart/element/element.dart' show ClassElement, Element;

class UnawaitedFuturesVisitor extends RecursiveAstVisitor {
  final unawaitedFutures = <AstNode>[];

  @override
  void visitExpressionStatement(ExpressionStatement node) {
    _checkExpressionStatement(node);
    node.visitChildren(this);
  }

  void _checkExpressionStatement(ExpressionStatement node) {
    var expr = node?.expression;
    if (expr is AssignmentExpression) return;

    var type = expr?.staticType;
    if (_isFutureClass(type?.element)) {
      // Ignore a couple of special known cases.
      if (_isFutureDelayedInstanceCreationWithComputation(expr) ||
          _isMapPutIfAbsentInvocation(expr)) {
        return;
      }

      // Future expression statement that isn't awaited in an async function:
      // while this is legal, it's a very frequent sign of an error.
      var enclosingFunctionBody = _findEnclosingFunctionBody(node);
      if (enclosingFunctionBody.isAsynchronous) {
        unawaitedFutures.add(node);
      }
    }
  }

  /// Detects `new Future.delayed(duration, [computation])` creations with a
  /// computation.
  bool _isFutureDelayedInstanceCreationWithComputation(Expression expr) =>
      expr is InstanceCreationExpression &&
      _isFutureClass(expr.staticElement?.enclosingElement) &&
      expr.constructorName?.name?.name == 'delayed' &&
      expr.argumentList.arguments.length == 2;

  /// Detects Map.putIfAbsent invocations.
  bool _isMapPutIfAbsentInvocation(Expression expr) =>
      expr is MethodInvocation &&
      expr.methodName.name == 'putIfAbsent' &&
      _isMap(expr.methodName.staticElement?.enclosingElement);

  bool _isFutureClass(Element e) =>
      e is ClassElement && e.name == 'Future' && e.library?.isDartAsync;

  bool _isMap(Element e) =>
      e is ClassElement && e.name == 'Map' && e.library?.isDartCore;

  FunctionBody _findEnclosingFunctionBody(AstNode node) {
    while (node != null && node is! FunctionBody) {
      node = node.parent;
    }
    return node;
  }
}

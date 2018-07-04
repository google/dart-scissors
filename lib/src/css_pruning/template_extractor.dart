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
library scissors.src.css_pruning.template_extractor;

import 'dart:async';

import 'package:barback/barback.dart' show Transform, Asset, AssetId;
import 'package:analyzer/analyzer.dart';
import 'package:path/path.dart';

import '../utils/path_resolver.dart';

Future<List<String>> extractTemplates(
    Transform transform, Asset dartAsset, AssetId cssAssetId) async {
  String dartSource = await dartAsset.readAsString();

  var unit = parseCompilationUnit(dartSource, suppressErrors: true);
  var templates = <String>[];
  var cssUrl = pathResolver.assetIdToUri(cssAssetId);

  var dartAssetId = dartAsset.id;
  String _resolveRelativeUrl(String url) {
    if (url == null || url.contains(':')) return url;

    var path = '${dirname(dartAssetId.path)}/$url'.replaceAll('/./', '');
    return pathResolver.assetIdToUri(new AssetId(dartAssetId.package, path));
  }

  for (var decl in unit.declarations) {
    if (decl is ClassDeclaration) {
      for (var meta in decl.metadata) {
        String annotationName = meta.name.name;
        evalArg(String argumentName) {
          var expr = _findNamedArgument(meta.arguments, argumentName);
          var result = expr == null ? null : _eval(expr);
          return result;
        }

        try {
          // Handle Angular1's Component.{template, cssUrl}
          // and Angular2's View.{template, styleUrls}.
          if (annotationName == 'View' || annotationName == 'Component') {
            var template = evalArg('template');
            if (template != null) {
              List<String> styleUrls =
                  (evalArg('styleUrls') ?? [evalArg('cssUrl')]).cast<String>();
              // stderr.writeln('\ncssUrl = $cssUrl, styleUrls = $styleUrls');
              if (styleUrls.map(_resolveRelativeUrl).contains(cssUrl)) {
                templates.add(template);
              }
            }
          }
        } catch (e, s) {
          print('$e\n$s');
          throw e;
        }
      }
    }
  }
  return templates;
}

dynamic _eval(Expression expr) {
  if (expr == null) return null;
  if (expr is SimpleStringLiteral) return expr.stringValue;
  if (expr is ListLiteral) return expr.elements.map(_eval).toList();
  throw new ArgumentError(
      "Unsupported literal type: ${expr.runtimeType} ($expr)");
}

Expression _findNamedArgument(ArgumentList argumentList, String name) {
  for (var arg in argumentList.arguments) {
    if (arg is AssignmentExpression &&
        arg.leftHandSide is Identifier &&
        (arg.leftHandSide as Identifier).name == name) {
      return arg.rightHandSide;
    } else if (arg is NamedExpression && arg.name.label.name == name) {
      return arg.expression;
    }
  }
  return null;
}

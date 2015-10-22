library scissors.template_extractor;

import 'dart:async';

import 'package:barback/barback.dart' show Transform, Asset, AssetId;
import 'package:analyzer/analyzer.dart';

Future<List<String>> extractTemplates(Transform transform, Asset dartAsset, AssetId cssAssetId) async {
  String dartSource = await dartAsset.readAsString();

  var unit = parseCompilationUnit(dartSource, suppressErrors: true);
  var templates = <String>[];
  var cssUrl = _assetIdToUri(cssAssetId);

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
              List styleUrls = evalArg('styleUrls') ?? [evalArg('cssUrl')];
              // stderr.writeln('\ncssUrl = $cssUrl, styleUrls = $styleUrls');
              if (styleUrls.contains(cssUrl)) {
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

dynamic _eval(Literal expr) {
  if (expr == null) return null;
  if (expr is SimpleStringLiteral) return expr.stringValue;
  if (expr is ListLiteral) return expr.elements.map(_eval).toList();
  throw new ArgumentError("Unsupported literal type: ${expr.runtimeType} ($expr)");
}

String _assetIdToUri(AssetId id) {
  var path = id.path;
  if (path.startsWith('lib/')) path = path.substring('lib/'.length);
  return 'package:${id.package}/$path';
}

Expression _findNamedArgument(ArgumentList argumentList, String name) {
  for (var arg in argumentList.arguments) {
    if (arg is AssignmentExpression && arg.leftHandSide is Identifier
        && arg.leftHandSide.name == name) {
      return arg.rightHandSide;
    } else if (arg is NamedExpression && arg.name.label.name == name) {
      return arg.expression;
    }
  }
  return null;
}

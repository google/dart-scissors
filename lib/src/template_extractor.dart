library scissors.template_extractor;

import 'dart:async';

import 'package:barback/barback.dart' show Transform, Asset, AssetId;

import 'package:code_transformers/resolver.dart';

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/constant.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/source.dart';

part '_asset_based_source.dart';

class TemplateExtractor {
  final Resolvers resolvers;

  TemplateExtractor(this.resolvers);

  Future<String> extractTemplate(Transform transform, Asset dartAsset) async {
    String dartSource = await dartAsset.readAsString();
    Resolver resolver = await resolvers.get(transform, [dartAsset.id]);

    AnalysisContext analysisContext = new AnalysisContextImpl()
        ..analysisOptions = resolvers.options ?? new AnalysisOptionsImpl();

    var unit = parseCompilationUnit(dartSource, suppressErrors: true);
    LibraryDirective libDirective =
        unit.directives.firstWhere((d) => d is LibraryDirective, orElse: () => null);
    // var source = analysisContext.sources.single;
    //var source = analysisContext.sourceFactory.forUri('package:${dartAsset.id.package}:${dartAsset.id.path}');
    var source = new _AssetBasedSource(dartAsset, dartSource);
    var unitElement = new CompilationUnitElementImpl(dartAsset.id.path)
        ..source = source
        ..librarySource = source;
    unit.element = unitElement;
    var libElement = new LibraryElementImpl.forNode(
        analysisContext, libDirective?.name ?? new LibraryIdentifier([]));
    libElement.definingCompilationUnit = unitElement;

    for (var decl in unit.declarations) {
      if (decl is ClassDeclaration) {
        for (var meta in decl.metadata) {
          String annotationName = meta.name.name;
          // Handle Angular1's Component.template and Angular2's View.template.
          if (annotationName == 'View' || annotationName == 'Component') {
            var template = _findNamedArgument(meta.arguments, 'template');
            if (template != null && template is StringLiteral) {
              return _evalString(template, resolver, libElement);
            }
          }
        }
      }
    }
    throw new StateError('No template found in ${dartAsset.id}');
  }

  String _evalString(StringLiteral expr, Resolver resolver, LibraryElement libElement) {
    var result = resolver.evaluateConstant(libElement, expr);
    if (result.errors.isNotEmpty) {
      throw new StateError(result.errors.map((e) => e.message).join("\n"));
    }
    return result.value.stringValue;
  }
}

Expression _findNamedArgument(ArgumentList argumentList, String name) {
  for (var arg in argumentList.arguments) {
    if (arg is AssignmentExpression
        && arg.leftHandSide is Identifier) {
      if (arg.leftHandSide.name == name) {
        return arg.rightHandSide;
      }
    }
  }
  return null;
}

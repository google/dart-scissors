import 'dart:async';
import 'package:analyzer/analyzer.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/src/context/builder.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:front_end/src/base/source.dart';
import 'package:path/path.dart' as path;

import 'escaping_locals.dart';
import 'format_knowledge.dart';
import 'flow_aware_nullability_inference.dart';

Future<String> annotateSourceWithNullability(Source source) async {
  try {
    final dartSdkPath = new String.fromEnvironment('DART_SDK',
        defaultValue: '/usr/local/opt/dart/libexec');
    final analysisRoot = path.current;

    final resourceProvider = PhysicalResourceProvider.INSTANCE;
    final contextBuilderOptions = new ContextBuilderOptions();
    final contextBuilder = new ContextBuilder(resourceProvider,
        new DartSdkManager(dartSdkPath, true), new ContentCache(),
        options: contextBuilderOptions);

    final analysisOptions = contextBuilder.getAnalysisOptions(analysisRoot);
    final sdk = contextBuilder.findSdk(null, analysisOptions);
    final resolvers = [
      new DartUriResolver(sdk),
      new ResourceUriResolver(resourceProvider)
    ];

    final context = AnalysisEngine.instance.createAnalysisContext()
      ..sourceFactory = new SourceFactory(resolvers);

    final changeSet = new ChangeSet()..addedSource(source);
    context.applyChanges(changeSet);
    final libElement = context.computeLibraryElement(source);
    final unit = context.resolveCompilationUnit(source, libElement);

    // print('unit: $unit');
    bool isNullable(Expression expr) {
      return expr is NullLiteral || expr is! Literal;
    }

    final localsToSkip = findLocalsMutatedInEscapingExecutableElements(unit, isNullable);
    final primitives = new Set.from(['int', 'num', 'bool', 'String']);
    final nullableLocalInference =
        new FlowAwareNullableLocalInference(localsToSkip,
          isStaticallyNullable: isNullable,
          hasPrimitiveType: (expr) {
            // TODO: use something much cleaner.
            final type = expr.staticType;
            return primitives.contains('$type');
          });
    unit.accept(nullableLocalInference);

    final formattedUnits = formatSourcesWithKnowledge(
        nullableLocalInference.results, {unit: source});
    final result = formattedUnits[unit];
    // print(result);
    return result ?? source.contents.data;
  } catch (e, s) {
    print('$e\n$s');
    throw e;
  }
}

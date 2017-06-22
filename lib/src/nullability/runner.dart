import 'dart:async';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/src/context/builder.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:front_end/src/base/source.dart';
import 'package:path/path.dart' as path;
import 'package:scissors/src/nullability/escaping_locals.dart';
import 'package:scissors/src/nullability/format_knowledge.dart';
import 'package:scissors/src/nullability/nullability_inference.dart';

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
    final localsToSkip = findLocalsMutatedInEscapingExecutableElements(unit);
    final nullableLocalInference =
        new FlowAwareNullableLocalInference(localsToSkip);
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

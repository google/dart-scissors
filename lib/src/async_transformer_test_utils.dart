library scissors.testing.async_transformer_test_utils;

import 'dart:async';
import 'package:barback/barback.dart';
import 'package:code_transformers/tests.dart';
import 'package:test/test.dart';

/// TODO(ochafik): Send this as a PR to quiver-dart.
Future<Map<String, String>> _awaitValues(Map<String, dynamic> map) {
  final result = <String, String>{};
  final futures = <Future>[];
  map.forEach((key, futureValue) {
    if (futureValue is Future) {
      futures.add(futureValue.then((value) {
        result[key] = value;
      }));
    } else {
      result[key] = futureValue;
    }
  });
  if (futures.isEmpty) return new Future.value(result);
  return Future.wait(futures).then((_) => result);
}

/// Defines a test which invokes [applyTransformers].
/// Same as [testPhases] but takes future input values, which can be read
/// asynchronously from local files.
///
/// TODO(ochafik): Send this as a PR to code_transformers.
testPhasesAsync(String testName, List<List<Transformer>> phases,
    Map<String, dynamic> futureInputs,
    Map<String, dynamic> futureResults,
    [List<String> messages,
    StringFormatter formatter = StringFormatter.noTrailingWhitespace]) {

  test(testName, () async => applyTransformers(phases,
      inputs: await _awaitValues(futureInputs),
      results: await _awaitValues(futureResults),
      messages: messages,
      formatter: formatter));
}

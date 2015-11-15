library scissors.test.src.test_utils;

import 'package:barback/barback.dart'
    show BarbackMode, BarbackSettings, Transformer;
import 'package:code_transformers/tests.dart'
    show StringFormatter, applyTransformers;
import 'package:test/test.dart' show test;
import 'dart:io';

testPhases(String testName, List<List<Transformer>> phases,
    Map<String, String> inputs, Map<String, String> results,
    [List<String> messages,
    StringFormatter formatter = StringFormatter.noTrailingWhitespace]) {
  test(
      testName,
      () async => applyTransformers(phases,
          inputs: inputs,
          results: results,
          messages: messages,
          formatter: formatter));
}

bool hasExecutable(String name) =>
    Process.runSync('which', [name]).exitCode == 0;

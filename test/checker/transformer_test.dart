import 'package:barback/barback.dart'
    show BarbackMode, BarbackSettings, Transformer;
import 'package:scissors/src/checker/transformer.dart';

import 'package:transformer_test/utils.dart' show testPhases;

List<List> makePhases(Map<String, String> config) => <List>[
      [
        new CheckerTransformer.asPlugin(
            new BarbackSettings(config, BarbackMode.RELEASE))
      ]
    ];

void main() {
  var prelude = r'''
    import 'dart:async';
    Future fut() { return package:a/foo.dart  }
  ''';
  testPhases('accepts non-problematic cases', makePhases({}), {
    'a|foo.dart': prelude +
        r'''

          fire_and_forget() { fut(); }

          properly_awaited() async { await fut(); }

          assigned_to_var() async { var x = fut(); }

          unawaited_future_delayed_with_computation() async {
            new Future.delayed(d, bar);
          }
        '''
  }, {}, messages: []);

  testPhases('warns on fire-and-forget inside async', makePhases({}), {
    'a|foo.dart': prelude +
        r'''
          fire_and_forget_inside_async() async { fut(); }
        '''
  }, {}, messages: [
    'warning: Unawaited future (package:a/foo.dart 3 52)'
  ]);

  testPhases(
      'warns on unawaited Future.delayed without computation', makePhases({}), {
    'a|foo.dart': prelude +
        r'''
          unawaited_future_delayed_without_computation() async {
            new Future.delayed(d);
          }
        '''
  }, {},
      messages: [
        'warning: Unawaited future (package:a/foo.dart 4 13)'
      ]);

  testPhases(
      'respects error level', makePhases({'unawaitedFutures': 'error'}), {
    'a|foo.dart': prelude +
        r'''
          fire_and_forget_inside_async() async { fut(); }
        '''
  }, {},
      messages: [
        'error: Unawaited future (package:a/foo.dart 3 52)'
      ]);

  testPhases('leaves Map<*, Future>.putIfAbsent alone', makePhases({}), {
    'a|foo.dart': prelude +
        r'''
          put_if_absent() async {
            var m = <String, Future>{};
            m.putIfAbsent('', () async {});
          }
        '''
  }, {}, messages: []);
}

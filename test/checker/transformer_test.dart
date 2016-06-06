import 'package:barback/barback.dart' show BarbackMode, BarbackSettings;
import 'package:scissors/src/checker/transformer.dart'
    show CheckerTransformer, unawaitedFutureMessage;

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
    'warning: $unawaitedFutureMessage (package:a/foo.dart 3 52)'
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
        'warning: $unawaitedFutureMessage (package:a/foo.dart 4 13)'
      ]);

  testPhases(
      'respects error level', makePhases({'unawaitedFutures': 'error'}), {
    'a|foo.dart': prelude +
        r'''
          fire_and_forget_inside_async() async { fut(); }
        '''
  }, {},
      messages: [
        'error: $unawaitedFutureMessage (package:a/foo.dart 3 52)'
      ]);

  testPhases('respects ignore comments', makePhases({}), {
    'a|foo.dart': prelude +
        r'''
          fire_and_forget_inside_async() async {
            // ignore: UNAWAITED_FUTURE
            fut();
          }
        '''
  }, {}, messages: []);

  testPhases(
      'respects ignore setting', makePhases({'unawaitedFutures': 'ignore'}), {
    'a|foo.dart': prelude +
        r'''
        fire_and_forget_inside_async() async {
          fut();
        }
      '''
  }, {},
      messages: []);

  testPhases('leaves Map<*, Future>.putIfAbsent alone', makePhases({}), {
    'a|foo.dart': prelude +
        r'''
          put_if_absent() async {
            var m = <String, Future>{};
            m.putIfAbsent('', () async {});
          }
        '''
  }, {}, messages: []);

  testPhases('supports part files', makePhases({}), {
    'a|foo.dart': r'''
          library foo;
          import 'dart:async';
          part 'foo_part.dart';

          Future foo() => null;
        ''',
    'a|foo_part.dart': prelude +
        r'''
          in_part() async {
            foo();
          }
        '''
  }, {}, messages: [
    'warning: $unawaitedFutureMessage (package:a/foo_part.dart 4 13)'
  ]);
}

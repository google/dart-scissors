import 'dart:io';

import 'package:scissors/src/utils/path_resolver.dart';
import 'package:scissors/src/utils/process_utils.dart';
import 'package:scissors/src/compass/sassc_with_compass_functions.dart';
import 'package:test/test.dart';
import 'dart:async';

_checkSassCOutputAgainstCompass(String input) async {
  var sassc = await pathResolver.resolveExecutable(pathResolver.defaultSassCPath);
  var sass = await pathResolver.resolveExecutable(pathResolver.defaultRubySassPath);
  var args = [
    '-I', await pathResolver.resolvePath('lib/src/compass'),
    '-I', compassStylesheetsPath,
  ];

  Future<String> run(
      String name, String exec, List<String> args, String input) async {
    var stopwatch = new Stopwatch()..start();
    var result = successString(name, await pipeInAndOutOfNewProcess(
        await Process.start(exec, args), input));
    stopwatch.stop();
    print('Executed $name in ${stopwatch.elapsedMilliseconds} millis');
    return result;
  }

  var sasscResult = await run(
      'SassC', sassc, args, "@import 'polyfills';\n" + input);
  var sassResult = await run(
      'Compass', sass, ['--compass', '--scss']..addAll(args), input);
  expect(sasscResult, sassResult);
  // print(sasscResult); // For debug purposes.
}

main() async {
  group('compass polyfills', () {

    test('support box-sizing & flexbox', () async {
      await _checkSassCOutputAgainstCompass(r'''
        @import 'compass/css3';

        .box {
          @include box-sizing;
        }

        .flex {
          @include display-flex;
          @include flex-direction(row);
        }
      ''');
    });

    test('support animations & transitions', () async {
      await _checkSassCOutputAgainstCompass(r'''
        @import 'compass/css3';

        .animation {
          @include animation(border);
        }

        .transition {
          @include single-transition;
        }
      ''');
    });

    test('support user-select', () async {
      await _checkSassCOutputAgainstCompass(r'''
        @import 'compass/css3';

        .select {
          @include user-select(text);
        }
      ''');
    });

    test('support transforms', () async {
      await _checkSassCOutputAgainstCompass(r'''
        @import 'compass/css3';

        .transform2d {
          @include transform-origin;
        }

        .transform3d {
          @include transform-style;
        }
      ''');
    });

    test('replicate browsers & browser-prefixes functions', () async {
      await _checkSassCOutputAgainstCompass(r'''
        @import 'compass/css3';

        .browsers {
          @each $prefix in browser-prefixes(browsers()) {
            #{$prefix}: browsers($prefix);
          }
        }

        .prefixes {
          @each $browser in browsers() {
            #{$browser}: browser-prefixes($browser);
          }
        }
      ''');
    });
  });
}

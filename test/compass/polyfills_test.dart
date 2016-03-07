import 'dart:io';

import 'package:scissors/src/utils/path_resolver.dart';
import 'package:scissors/src/utils/process_utils.dart';
import 'package:scissors/src/compass/sassc_with_compass_functions.dart';
import 'package:test/test.dart';

_checkSassCOutputAgainstCompass(String input) async {
  var sassc = await pathResolver.resolveExecutable(pathResolver.defaultSassCPath);
  var sass = await pathResolver.resolveExecutable(pathResolver.defaultRubySassPath);
  var args = [
    '-I', await pathResolver.resolvePath('lib/src/compass'),
    '-I', compassStylesheetsPath,
  ];

  var sasscResult = successString('SassC', await pipeInAndOutOfNewProcess(
      await Process.start(sassc, args),
      "@import 'compass_polyfills';\n" + input));
  var sassResult = successString('Compass', await pipeInAndOutOfNewProcess(
      await Process.start(sass, ['--compass', '--scss']..addAll(args)),
      input));
  expect(sasscResult, sassResult);
  print(sasscResult); // For debug purposes.
}

main() async {
  group('compass polyfills', () {

    test('work with box-sizing & flexbox', () async {
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

    test('work with animations & transitions', () async {
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

    test('work with user-select', () async {
      await _checkSassCOutputAgainstCompass(r'''
        @import 'compass/css3';

        .select {
          @include user-select(text);
        }
      ''');
    });

    test('work with transforms', () async {
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

    test('replicate browsers & browser-prefixes', () async {
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
// bin/sassc_with_compass_functions.dart \
//   -I . -I `gem environment gemdir`/gems/compass-core-1.0.3/stylesheets \
//   test/compass/prefix_usage_polyfills.scss
//
// sass --compass test/compass/prefix_usage.scss

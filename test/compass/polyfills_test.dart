import 'dart:async';
import 'dart:io';

import 'package:scissors/src/utils/path_resolver.dart';
import 'package:scissors/src/utils/process_utils.dart';
import 'package:scissors/src/compass/sassc_with_compass_functions.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

_expectSassOutput(String input, String expectedOutput, {bool useSassC}) async {
  var args = [
    '-I',
    path.join(path.dirname(Platform.script.path), '../../lib/compass'),
    '-I',
    'lib/compass',
    '-I',
    compassStylesheetsPath,
  ];

  Future<String> run(
      String name, String exec, List<String> args, String input) async {
    //print('EXEC:\necho "$input" | $exec ${args.join(' ')}');
    var stopwatch = new Stopwatch()..start();
    var result = successString(name,
        await pipeInAndOutOfNewProcess(await Process.start(exec, args), input));
    stopwatch.stop();
    print('Executed $name in ${stopwatch.elapsedMilliseconds} millis');
    return result;
  }

  var output;
  if (useSassC) {
    var sassc =
        await pathResolver.resolveExecutable(pathResolver.defaultSassCPath);
    output = await run('SassC', sassc, args, "@import 'polyfills';\n" + input);
  } else {
    var sass =
        await pathResolver.resolveExecutable(pathResolver.defaultRubySassPath);
    output = await run(
        'Compass', sass, ['--compass', '--scss']..addAll(args), input);
  }

  expect(_normalize(output), _normalize(expectedOutput));
}

String _normalize(String css) {
  css = css.replaceAll('\n\n', '\n');
  return css;
}

main() async {
  runAllTests({bool useSassC}) {
    test('support box-sizing & flexbox', () async {
      await _expectSassOutput(
          r'''
        @import 'compass/css3';

        .box {
          @include box-sizing;
        }

        .flex {
          @include display-flex;
          @include flex-direction(row);
        }
      ''',
          '.box {\n'
          '  -moz-box-sizing: border-box;\n'
          '  -webkit-box-sizing: border-box;\n'
          '  box-sizing: border-box; }\n'
          '.flex {\n'
          '  display: -webkit-flex;\n'
          '  display: flex;\n'
          '  -webkit-flex-direction: row;\n'
          '  flex-direction: row; }\n',
          useSassC: useSassC);
    });

    test('support inline-block', () async {
      await _expectSassOutput(
          r'''
        @import 'compass/css3/inline-block';

        .inline-block {
          @include inline-block;
        }
      ''',
          '.inline-block {\n'
          '  display: inline-block;\n'
          '  vertical-align: middle;\n'
          '  *vertical-align: auto;\n'
          '  *zoom: 1;\n'
          '  *display: inline; }\n',
          useSassC: useSassC);
    });

    test('support box-shadow', () async {
      await _expectSassOutput(
          r'''
        @import 'compass/css3';

        .box-shadow {
          @include single-box-shadow;
        }
      ''',
          '.box-shadow {\n'
          '  -moz-box-shadow: 0px 5px #333333;\n'
          '  -webkit-box-shadow: 0px 5px #333333;\n'
          '  box-shadow: 0px 5px #333333; }\n',
          useSassC: useSassC);
    });

    test('support animations & transitions', () async {
      await _expectSassOutput(
          r'''
        @import 'compass/css3';

        .animation {
          @include animation(border);
        }

        .transition {
          @include single-transition;
        }
      ''',
          '.animation {\n'
          '  -moz-animation: border;\n'
          '  -webkit-animation: border;\n'
          '  animation: border; }\n'
          '.transition {\n'
          '  -moz-transition: all 1s;\n'
          '  -o-transition: all 1s;\n'
          '  -webkit-transition: all 1s;\n'
          '  transition: all 1s; }\n',
          useSassC: useSassC);
    });

    test('support user-select', () async {
      await _expectSassOutput(
          r'''
        @import 'compass/css3';

        .select {
          @include user-select(text);
        }
      ''',
          '.select {\n'
          '  -moz-user-select: text;\n'
          '  -ms-user-select: text;\n'
          '  -webkit-user-select: text;\n'
          '  user-select: text; }\n',
          useSassC: useSassC);
    });

    test('support transforms', () async {
      await _expectSassOutput(
          r'''
        @import 'compass/css3';

        .transform2d {
          @include transform-origin;
        }

        .transform3d {
          @include transform-style;
        }
      ''',
          '.transform2d {\n'
          '  -moz-transform-origin: 50% 50%;\n'
          '  -ms-transform-origin: 50% 50%;\n'
          '  -webkit-transform-origin: 50% 50%;\n'
          '  transform-origin: 50% 50%; }\n'
          '.transform3d {\n'
          '  -moz-transform-style: preserve-3d;\n'
          '  -webkit-transform-style: preserve-3d;\n'
          '  transform-style: preserve-3d; }\n',
          useSassC: useSassC);
    });

    test('replicate browsers & browser-prefixes functions', () async {
      await _expectSassOutput(
          r'''
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
      ''',
          '.browsers {\n'
          '  -moz: android-firefox, firefox;\n'
          '  -ms: ie, ie-mobile;\n'
          '  -o: opera, opera-mini, opera-mobile;\n'
          '  -webkit: android, android-chrome, blackberry, chrome, ios-safari, opera, opera-mobile, safari; }\n'
          '.prefixes {\n'
          '  android: -webkit;\n'
          '  android-chrome: -webkit;\n'
          '  android-firefox: -moz;\n'
          '  blackberry: -webkit;\n'
          '  chrome: -webkit;\n'
          '  firefox: -moz;\n'
          '  ie: -ms;\n'
          '  ie-mobile: -ms;\n'
          '  ios-safari: -webkit;\n'
          '  opera: -o, -webkit;\n'
          '  opera-mini: -o;\n'
          '  opera-mobile: -o, -webkit;\n'
          '  safari: -webkit; }\n',
          useSassC: useSassC);
    });

    test('support filter', () async {
      await _expectSassOutput(
          r'''
        @import 'compass/css3/filter';
        .filter {
          @include filter(grayscale(100%));
        }
      ''',
          '.filter {\n'
          '  -webkit-filter: grayscale(100%);\n'
          '  filter: grayscale(100%); }\n',
          useSassC: useSassC);
    });

    test('support input-placeholder', () async {
      await _expectSassOutput(
          r'''
        @import 'compass/css3/user-interface';

        input[type="text"] {
          @include input-placeholder {
            color: white;
          }
        }
      ''',
          'input[type="text"]:-moz-placeholder {\n'
          '  color: white; }\n'
          'input[type="text"]::-moz-placeholder {\n'
          '  color: white; }\n'
          'input[type="text"]:-ms-input-placeholder {\n'
          '  color: white; }\n'
          'input[type="text"]::-webkit-input-placeholder {\n'
          '  color: white; }\n',
          useSassC: useSassC);
    });

    test('leaves linear-gradient intact', () async {
      await _expectSassOutput(
          r'''
        @import 'compass/css3';

        .gradient {
          background-image: linear-gradient(to bottom, #ffffff, #000000);
        }
        ''',
          '.gradient {\n'
          '  background-image: linear-gradient(to bottom, #ffffff, #000000); }\n',
          useSassC: useSassC);
    });
  }

  group('compass polyfills', () {
    runAllTests(useSassC: true);
  });
  if (Platform.environment['TEST_COMPASS_POLYFILLED_FUNCTIONS'] == 'true') {
    group('native compass functions', () {
      runAllTests(useSassC: false);
    });
  }
}

import 'dart:async';
import 'package:analyzer/src/string_source.dart';
import 'package:scissors/src/nullability/runner.dart';
import 'package:test/test.dart';

Future<String> annotate(String source) =>
    annotateSourceWithNullability(new StringSource(source, 'input.dart'));

main() {
  group('FlowAwareNullableLocalInference', () {
    test('simple flows', () async {
      expect(
          await annotate('''
        foo(x) {
          int y;
          if (x != null) x();
          if (y != null && x == y) x();
          x();
          x();
        }
      '''),
          '''
        foo(x) {
          int y;
          if (x != null) /*not-null*/x();
          if (y != null && x == /*not-null*/y) /*not-null*/x();
          x();
          /*not-null*/x();
        }
      ''');
    });

    test('escape analysis', () async {
      expect(
          await annotate('''
        foo(x, y, z) {
          x();
          y();
          z();
          (() => x = 1);
          setY() => y = 1;
          getZ() => z;
          x;
          y;
          z;
        }
      '''),
          '''
        foo(x, y, z) {
          x();
          y();
          z();
          (() => x = 1);
          setY() => y = 1;
          getZ() => /*not-null*/z;
          x;
          y;
          /*not-null*/z;
        }
      ''');
    });

    test('method calls', () async {
      expect(await annotate('bar(x) => x.f(x.a, x.b);'),
          'bar(x) => /*not-null*/x.f(x.a, /*not-null*/x.b);');
    });

    test('negation', () async {
      expect(await annotate('bar(x) { if (!(x == null)) x(); }'),
          'bar(x) { if (!(x == null)) /*not-null*/x(); }');
    });

    test('increment / decrement operators', () async {
      expect(
          await annotate('''
        m(x, y, z) {
          x; x++; x;
          y; y--; y;
        }
      '''),
          '''
        m(x, y, z) {
          x; x++; /*not-null*/x;
          y; y--; /*not-null*/y;
        }
      ''');
      expect(
          await annotate('''
        m(x, y, z) {
          x; ++x; x;
          y; --y; y;
        }
      '''),
          '''
        m(x, y, z) {
          x; ++x; /*not-null*/x;
          y; --y; /*not-null*/y;
        }
      ''');
    });

    test('conditional expressions', () async {
      expect(
          await annotate('''
        bar(x, c) {
          (x.a ? x.b && c != null : x.c && c != null)
            && c.d;
        }
      '''),
          '''
        bar(x, c) {
          (x.a ? /*not-null*/x.b && c != null : /*not-null*/x.c && c != null)
            && /*not-null*/c.d;
        }
      ''');
    });

    test('assigments', () async {
      expect(
          await annotate('''
        bar(x) {
          var y;
          x();
          y = x;
          y();
        }
      '''),
          '''
        bar(x) {
          var y;
          x();
          y = /*not-null*/x;
          /*not-null*/y();
        }
      ''');
    });

    test('cascades', () async {
      expect(await annotate('m(x) => x..f(x.y);'),
          'm(x) => /*not-null*/x..f(x.y);');
      expect(await annotate('m(x) => x..f(x)..g(x);'),
          'm(x) => x..f(x)..g(/*not-null*/x);');
      expect(await annotate('m(x) => (x..f(x)..g(x)) && x.y();'),
          'm(x) => (x..f(x)..g(/*not-null*/x)) && /*not-null*/x.y();');
    });
  });
}

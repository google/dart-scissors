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

    test('simple operators', () async {
      expect(
          await annotate('''
        m(a, b) {
          a() + b();
          a;
          b;
        }
      '''),
          '''
        m(a, b) {
          a() + b();
          /*not-null*/a;
          /*not-null*/b;
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

    test('reassignments', () async {
      expect(
          await annotate('''
        m(x, y) {
          x();
          x;
          x = y;
          x;
          x();
          x;
        }
      '''),
          '''
        m(x, y) {
          x();
          /*not-null*/x;
          /*not-null*/x = y;
          x;
          x();
          /*not-null*/x;
        }
      ''');
    });

    test('if statements vs. exceptions', () async {
      expect(
          await annotate('''
        m(a, b) {
          if (a() && b()) {
            a;
            b;
          } else {
            a;
            b;
          }
          a;
          b;
        }
      '''),
          '''
        m(a, b) {
          if (a() && b()) {
            /*not-null*/a;
            /*not-null*/b;
          } else {
            /*not-null*/a;
            /*not-null*/b;
          }
          /*not-null*/a;
          /*not-null*/b;
        }
      ''');
    });

    test('while loops', () async {
      expect(
          await annotate('''
        m(a, b, c) {
          while (a() + b()) {
            a;
            b;
            a = null;
            a;
            c();
          }
          a;
          b;
          c;
        }
      '''),
          '''
        m(a, b, c) {
          while (a() + b()) {
            a;
            /*not-null*/b;
            a = null;
            a;
            c();
          }
          a;
          /*not-null*/b;
          c;
        }
      ''');
    });

    test('do-while loops', () async {
      expect(
          await annotate('''
        m(x, a, b, c) {
          x();
          x;
          do {
            a;
            b;
            a();
            c();
            x = null;
          } while (a() + b());
          x;
          a;
          b;
          c;
        }
      '''),
          '''
        m(x, a, b, c) {
          x();
          /*not-null*/x;
          do {
            a;
            b;
            a();
            c();
            x = null;
          } while (/*not-null*/a() + b());
          x;
          /*not-null*/a;
          /*not-null*/b;
          /*not-null*/c;
        }
      ''');
    });

    test('foreach loops', () async {
      expect(
          await annotate('''
        m(c, d) {
          for (var i in c) {
            c;
            d();
          }
          c;
          d;
        }
      '''),
          '''
        m(c, d) {
          for (var i in c) {
            /*not-null*/c;
            d();
          }
          /*not-null*/c;
          d;
        }
      ''');
      expect(
          await annotate('''
        m(c, x) {
          x();
          x;
          for (var i in c()) {
            c;
            x = null;
          }
          c;
          x;
        }
      '''),
          '''
        m(c, x) {
          x();
          /*not-null*/x;
          for (var i in c()) {
            /*not-null*/c;
            x = null;
          }
          /*not-null*/c;
          x;
        }
      ''');
    });

    test('for loops', () async {
      expect(
          await annotate('''
        m(a, b, c) {
          for (var i = a(); i < b(); c()) {
            a();
            b();
            c();
          }
          a;
          b;
          c;
        }
      '''),
          '''
        m(a, b, c) {
          for (var i = a(); i < b(); c()) {
            /*not-null*/a();
            /*not-null*/b();
            c();
          }
          /*not-null*/a;
          /*not-null*/b;
          c;
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

    test('try / catch', () async {
      expect(
          await annotate('''
        m(a, b, c, d) {
          try {
            a();
            b();
            c();
          } on NullThrownError {
            a();
            b();
          } on CastError {
            b();
            c();
          } finally {
            a;
            b;
            c;
            d();
          }
          a;
          b;
          c;
          d;
        }
      '''),
          '''
        m(a, b, c, d) {
          try {
            a();
            b();
            c();
          } on NullThrownError {
            a();
            b();
          } on CastError {
            b();
            c();
          } finally {
            a;
            /*not-null*/b;
            c;
            d();
          }
          a;
          /*not-null*/b;
          c;
          /*not-null*/d;
        }
      ''');
    });

    test('switches', () async {
      expect(
          await annotate('''
        m(a, b, c, d, e) {
          d();
          e();
          switch (a) {
            case 1:
              b();
            case 2:
              c();
              d = null;
              break;
            default:
              e = null;
          }
          a;
          b;
          c;
          d;
          e;
        }
      '''),
          '''
        m(a, b, c, d, e) {
          d();
          e();
          switch (a) {
            case 1:
              b();
            case 2:
              c();
              d = null;
              break;
            default:
              e = null;
          }
          /*not-null*/a;
          b;
          c;
          d;
          e;
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

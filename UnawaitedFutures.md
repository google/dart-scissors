Forgetting to await a future (in expression statements) seems to be a common
cause of errors / test flakiness.

The `scissors/src/checker/transformer` transformer warns against unawaited
futures in async method bodies, with a couple of hard-coded special cases.

```dart
Examples (given `Future fut();`):

  foo()       { fut(); }           // OK: assuming fire-and-forget semantics.
                                   //     Could consider a hint here.
  foo() async { fut(); }           // Warning: 'implicit downcast of Future to void'
                                   //          The message should change, of course.
  foo() async { await fut(); }     // OK
  foo() async { var x = fut(); }   // OK
  foo() async {
    new Future.delayed(d);         // Warning
    new Future.delayed(d, bar);    // OK: special case
  }
  foo() async {
    var map = <String, Future>{};
    map.putIfAbsent('foo', fut()); // OK: special case
  }
```

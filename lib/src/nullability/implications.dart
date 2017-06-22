import 'package:analyzer/dart/element/element.dart';

import 'knowledge.dart';

final _implicationsByKnowledgeAndExpressionValue = <Knowledge, Map<bool, int>>{
  Knowledge.isNullable: <bool, int>{
    true: Implication.isNullIfExpressionIsTrue,
    false: Implication.isNullIfExpressionIsFalse,
  },
  Knowledge.isNotNull: <bool, int>{
    true: Implication.isNotNullIfExpressionIsTrue,
    false: Implication.isNotNullIfExpressionIsFalse,
  },
};

class Implication {
  static const isNotNull = 1;
  static const isNull = 2;
  static const isNotNullIfExpressionIsTrue = 4;
  static const isNotNullIfExpressionIsFalse = 8;
  static const isNullIfExpressionIsTrue = 16;
  static const isNullIfExpressionIsFalse = 32;

  static const _unconditionalMask = isNotNull | isNull;

  static const _ifExpressionIsTrueMask = _unconditionalMask |
      isNotNullIfExpressionIsTrue |
      isNullIfExpressionIsTrue;

  static const _ifExpressionIsFalseMask = _unconditionalMask |
      isNotNullIfExpressionIsFalse |
      isNullIfExpressionIsFalse;

  static const _isNullMask =
      isNull | isNullIfExpressionIsTrue | isNullIfExpressionIsFalse;

  static const _isNotNullMask =
      isNotNull | isNotNullIfExpressionIsTrue | isNotNullIfExpressionIsFalse;

  static int bindKnowledgeToBoolExpression(
      Knowledge knowledge, bool expression) {
    if (expression == null) throw 'unexpected expression: $expression';
    final map = _implicationsByKnowledgeAndExpressionValue[knowledge];
    if (map == null) throw 'unexpected knowledge: $knowledge';
    return map[expression];
  }

  /// For debug only
  static String flagsToString(int flags) {
    token(String desc, int flag) => (flags & flag) == flag ? desc : null;
    tokens(List<String> tokens) => tokens.where((t) => t != null).join(', ');

    var results = [];
    if ((flags & _isNotNullMask) != 0) {
      if ((flags & isNotNull) != 0) {
        results.add('notNull');
      } else {
        results.add('notNullIf(' +
            tokens([
              token('exprIsTrue', isNotNullIfExpressionIsTrue),
              token('exprIsFalse', isNotNullIfExpressionIsFalse),
            ]) +
            ')');
      }
    }
    if ((flags & _isNullMask) != 0) {
      if ((flags & isNull) != 0) {
        results.add('null');
      } else {
        results.add('nullIf(' +
            tokens([
              token('exprIsTrue', isNullIfExpressionIsTrue),
              token('exprIsFalse', isNullIfExpressionIsFalse),
            ]) +
            ')');
      }
    }
    return results.join(', ');
  }

  static int and(int left, int right) =>
      (left | right) & _ifExpressionIsTrueMask;

  static int or(int left, int right) =>
      (left | right) & _ifExpressionIsFalseMask;

  static int not(int flags) {
    var result = flags & _unconditionalMask;
    if ((flags & isNotNullIfExpressionIsTrue) != 0) {
      result |= isNotNullIfExpressionIsFalse;
    }
    if ((flags & isNotNullIfExpressionIsFalse) != 0) {
      result |= isNotNullIfExpressionIsTrue;
    }
    if ((flags & isNullIfExpressionIsTrue) != 0) {
      result |= isNullIfExpressionIsFalse;
    }
    if ((flags & isNullIfExpressionIsFalse) != 0) {
      result |= isNullIfExpressionIsTrue;
    }
    return result;
  }

  static int then(int first, int second) => asStatement(first | second);

  static int asStatement(int flags) => flags & _unconditionalMask;

  static Knowledge toKnowledge(int flags) => (flags & _isNullMask) != 0
      ? Knowledge.isNullable
      : (flags & _isNotNullMask) != 0 ? Knowledge.isNotNull : null;

  static int fromKnowledge(Knowledge knowledge) {
    if (knowledge == Knowledge.isNotNull) return isNotNull;
    if (knowledge == Knowledge.isNullable) return isNull;
    return 0;
  }

  static Knowledge getKnowledgeForRightAndOperand(int flags) =>
      toKnowledge(flags & _ifExpressionIsTrueMask);

  static Knowledge getKnowledgeForRightOrOperand(int flags) =>
      toKnowledge(flags & _ifExpressionIsFalseMask);

  static Knowledge getKnowledgeForNextOperation(int flags) =>
      toKnowledge(flags & _unconditionalMask);
}

class Implications {
  final Map<LocalElement, int /* Implication flags */ > data;

  Implications._(this.data);

  static final Implications empty = new Implications._(const {});

  factory Implications(Map<LocalElement, int> data) {
    Map<LocalElement, int> normalized;
    data?.forEach((k, v) {
      if (k != null && v != null) {
        if (normalized == null) {
          normalized = <LocalElement, int>{};
        }
        normalized[k] = v;
      }
    });
    return normalized == null ? empty : new Implications._(normalized);
  }

  /// For debug only
  @override
  String toString() {
    final results = [];
    data.forEach((v, flags) {
      results.add(v.name + ': ' + Implication.flagsToString(flags));
    });
    return '{' + results.join(', ') + '}';
  }

  Map<LocalElement, Knowledge> getKnowledgeForNextOperation() {
    final result = <LocalElement, Knowledge>{};
    data.forEach((v, i) {
      final knowledge = Implication.getKnowledgeForNextOperation(i);
      if (knowledge != null) {
        result[v] = knowledge;
      }
    });
    return result;
  }

  Map<LocalElement, Knowledge> getKnowledgeForAndRightOperand() {
    final result = <LocalElement, Knowledge>{};
    data.forEach((v, i) {
      final knowledge = Implication.getKnowledgeForRightAndOperand(i);
      if (knowledge != null) {
        result[v] = knowledge;
      }
    });
    return result;
  }

  Map<LocalElement, Knowledge> getKnowledgeForOrRightOperand() {
    final result = <LocalElement, Knowledge>{};
    data.forEach((v, i) {
      final knowledge = Implication.getKnowledgeForRightOrOperand(i);
      if (knowledge != null) {
        result[v] = knowledge;
      }
    });
    return result;
  }

  static bool _isEmpty(Implications i) =>
      i == null || identical(i, Implications.empty);

  static Implications subtract(Implications a, Set<LocalElement> locals) {
    if (_isEmpty(a)) return null;
    return new Implications(new Map.fromIterable(
        a.data.keys.where((k) => !locals.contains(k)),
        value: (k) => a.data[k]));
  }

  static Implications union(Implications a, Implications b) {
    if (_isEmpty(a)) return b;
    if (_isEmpty(b)) return a;
    return _combine(a, b, (ia, ib) => ia | ib);
  }

  static Implications intersect(Implications a, Implications b) {
    if (_isEmpty(a) || _isEmpty(b)) return null;
    return _combine(a, b, (ia, ib) => ia & ib);
  }

  static Implications then(Implications a, [Implications b]) {
    if (_isEmpty(a)) return _map(b, Implication.asStatement);
    if (_isEmpty(b)) return _map(a, Implication.asStatement);
    return _combine(a, b, Implication.then);
  }

  static Implications _combine(
      Implications a, Implications b, int combineSingle(int a, int b)) {
    final result = <LocalElement, int>{};
    mergedKeys() sync* {
      if (a != null) yield* a.data.keys;
      if (b != null) yield* b.data.keys;
    }

    for (final v in mergedKeys()) {
      result[v] = combineSingle((_isEmpty(a) ? null : a.data[v]) ?? 0,
          (_isEmpty(b) ? null : b.data[v]) ?? 0);
    }
    return new Implications(result);
  }

  static Implications _map(Implications implications, int f(int flags)) {
    final result = <LocalElement, int>{};
    implications?.data?.forEach((v, flags) => result[v] = f(flags));
    return new Implications(result);
  }

  static or(Implications a, Implications b) => _combine(a, b, Implication.or);
  static and(Implications a, Implications b) => _combine(a, b, Implication.and);
  static Implications not(Implications implications) =>
      _map(implications, Implication.not);
}

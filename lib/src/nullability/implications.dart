import 'package:analyzer/dart/element/element.dart';
import 'package:scissors/src/nullability/knowledge.dart';

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
  static const isNotNullIfExpressionDidNotThrow = 4;
  static const isNotNullIfExpressionIsTrue = 8;
  static const isNotNullIfExpressionIsFalse = 16;
  static const isNullIfExpressionIsTrue = 32;
  static const isNullIfExpressionIsFalse = 64;

  static const sequenceMask =
      isNotNull | isNull | isNotNullIfExpressionDidNotThrow;

  static const ifExpressionIsTrueMask =
      sequenceMask | isNotNullIfExpressionIsTrue | isNullIfExpressionIsTrue;

  static const ifExpressionIsFalseMask =
      sequenceMask | isNotNullIfExpressionIsFalse | isNullIfExpressionIsFalse;

  static const isNullMask =
      isNull | isNullIfExpressionIsTrue | isNullIfExpressionIsFalse;

  static const isNotNullMask = isNotNull |
      isNotNullIfExpressionDidNotThrow |
      isNotNullIfExpressionIsTrue |
      isNotNullIfExpressionIsFalse;

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
    if ((flags & isNotNullMask) != 0) {
      if ((flags & isNotNull) != 0) {
        results.add('notNull');
      } else {
        results.add('notNullIf(' +
            tokens([
              token('exprNotThrowing', isNotNullIfExpressionDidNotThrow),
              token('exprIsTrue', isNotNullIfExpressionIsTrue),
              token('exprIsFalse', isNotNullIfExpressionIsFalse),
            ]) +
            ')');
      }
    }
    if ((flags & isNullMask) != 0) {
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
      (left | right) & ifExpressionIsTrueMask;

  static int or(int left, int right) =>
      (left | right) & ifExpressionIsFalseMask;

  static int not(int flags) {
    var result = flags & sequenceMask;
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

  static int asStatement(int flags) => flags & sequenceMask;

  static Knowledge toKnowledge(int flags) => (flags & isNullMask) != 0
      ? Knowledge.isNullable
      : (flags & isNotNullMask) != 0 ? Knowledge.isNotNull : null;

  static int fromKnowledge(Knowledge knowledge) {
    if (knowledge == Knowledge.isNotNull) return isNotNull;
    if (knowledge == Knowledge.isNullable) return isNull;
    return 0;
  }

  static Knowledge getKnowledgeForRightAndOperand(int flags) =>
      toKnowledge(flags & ifExpressionIsTrueMask);

  static Knowledge getKnowledgeForRightOrOperand(int flags) =>
      toKnowledge(flags & ifExpressionIsFalseMask);

  static Knowledge getKnowledgeForNextOperation(int flags) =>
      toKnowledge(flags & sequenceMask);
}

class Implications {
  final Map<LocalElement, int /* Implication flags */ > data;

  Implications._(this.data);

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
    return normalized == null ? null : new Implications._(normalized);
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

  static Implications union(Implications a, Implications b) {
    if (a == null) return b;
    if (b == null) return a;
    return _combine(a, b, (ia, ib) => ia | ib);
  }

  static Implications intersect(Implications a, Implications b) {
    if (a == null || b == null) return null;
    return _combine(a, b, (ia, ib) => ia & ib);
  }

  static Implications then(Implications a, [Implications b]) {
    if (a == null) return _map(b, Implication.asStatement);
    if (b == null) return _map(a, Implication.asStatement);
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
      result[v] = combineSingle((a == null ? null : a.data[v]) ?? 0,
          (b == null ? null : b.data[v]) ?? 0);
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

import 'package:analyzer/analyzer.dart';

enum Knowledge { isNullable, isNotNull }

typedef bool ExpressionNullabilityPredicate(Expression expr);

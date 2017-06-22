import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/generated/source_io.dart';

import 'knowledge.dart';

class _Data implements Comparable<_Data> {
  final SimpleIdentifier identifier;
  final Knowledge knowledge;
  _Data(this.identifier, this.knowledge);

  @override
  int compareTo(_Data other) => identifier.beginToken.offset
      .compareTo(other.identifier.beginToken.offset);
}

Map<CompilationUnit, String> formatSourcesWithKnowledge(
    Map<LocalElement, Map<SimpleIdentifier, Knowledge>> data,
    Map<CompilationUnit, Source> sourceByUnit) {
  final dataPerSource = <CompilationUnit, List<_Data>>{};
  data.forEach((variable, map) => map.forEach((identifier, knowledge) {
        final unit = identifier.getAncestor((a) => a is CompilationUnit);
        dataPerSource
            .putIfAbsent(unit, () => <_Data>[])
            .add(new _Data(identifier, knowledge));
      }));
  final out = <CompilationUnit, String>{};
  dataPerSource.forEach((unit, List<_Data> list) {
    final source = sourceByUnit[unit];
    var result = source.contents.data;
    list.sort();
    for (final data in list.reversed) {
      final i = data.identifier.beginToken.offset;
      result = result.substring(0, i) +
          '/*${_knowledgeDesc[data.knowledge]}*/' +
          result.substring(i);
    }
    out[unit] = result;
  });
  return out;
}

final _knowledgeDesc = {
  Knowledge.isNullable: 'nullable',
  Knowledge.isNotNull: 'not-null'
};

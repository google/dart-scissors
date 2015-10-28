library scissors.source_maps.source_map_editor;

import 'dart:convert';

import 'package:source_maps/parser.dart';
import 'package:source_maps/source_maps.dart';
import 'package:source_span/source_span.dart';

import '../result.dart';
import 'package:path/path.dart';
import 'package:barback/barback.dart';
import 'dart:async';
import 'pos_converter.dart';

class _Edit implements Comparable<_Edit> {
  final int offset, oldLength, newLength;
  _Edit(this.offset, this.oldLength, this.newLength);

  @override
  int compareTo(_Edit other) => offset - other.offset;
}

class SourceMapEditor {
  final String filename;
  // final Mapping original;
  final SingleMapping original;
  final PosConverter sourcePosConverter;
  final PosConverter targetPosConverter;
  final _edits = <_Edit>[];

  SourceMapEditor(this.filename, this.original, this.sourcePosConverter, this.targetPosConverter);
  // if (original is MultiSectionMapping) {
  //   throw new StateError('TODO: MultiSectionMapping');
  // } else if (original is SingleMapping) {
  //   throw new StateError('TODO: MultiSectionMapping');
  // }

  void edit(int begin, int end, String text) {
    _edits.add(new _Edit(begin, end - begin, text.length));
  }

  String createSourceMap() {
    _edits.sort();
    var entries = <Entry>[];
    for (var line in original.lines) {
      for (var entry in line.entries) {
        var source = new SourceLocation(
            sourcePosConverter.getOffset(new Pos(entry.sourceLine, entry.sourceColumn)),
            sourceUrl: original.urls[entry.sourceUrlId],
            line: entry.sourceLine,
            column: entry.sourceColumn);
        var target = new SourceLocation(
            targetPosConverter.getOffset(new Pos(line.line, entry.column)),
            sourceUrl: original.urls[entry.sourceUrlId],
            line: line.line,
            column: entry.column);
        var identifierName = original.names[entry.sourceNameId];
        entries.add(new Entry(source, target, identifierName));
      }
    }
    var result = new SingleMapping.fromEntries(entries, filename);
    return JSON.encode(result.toJson());
  }

  // /// A line entry read from a source map.
  // class TargetLineEntry {
  //   final int line;
  //   List<TargetEntry> entries;
  //   TargetLineEntry(this.line, this.entries);
  //
  //   String toString() => '$runtimeType: $line $entries';
  // }
  //
  // /// A target segment entry read from a source map
  // class TargetEntry {
  //   final int column;
  //   final int sourceUrlId;
  //   final int sourceLine;
  //   final int sourceColumn;
  //   final int sourceNameId;
  //
  //   TargetEntry(this.column, [this.sourceUrlId, this.sourceLine,
  //       this.sourceColumn, this.sourceNameId]);

}

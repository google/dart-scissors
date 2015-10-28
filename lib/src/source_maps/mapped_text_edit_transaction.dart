library scissors.source_maps.mapped_text_edit_transaction;

import 'package:source_maps/parser.dart';
import 'package:source_maps/source_maps.dart';
import 'package:source_span/source_span.dart';

import '../result.dart';
import 'package:path/path.dart';
import 'package:barback/barback.dart';
import 'dart:async';
import 'pos_converter.dart';
import 'source_map_editor.dart';

class _MockNestedPrinter implements NestedPrinter {
  final String text;
  final String map;
  _MockNestedPrinter(this.text, this.map);

  @override noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class MappedTextEditTransaction implements TextEditTransaction {

  final TextEditTransaction _transaction;
  final SourceMapEditor _mapEditor;

  MappedTextEditTransaction(this._transaction, this._mapEditor);

  @override
  NestedPrinter commit() {
    var printer = _transaction.commit();
    return new _MockNestedPrinter(
      printer.text, _mapEditor.createSourceMap());
  }

  @override
  void edit(int begin, int end, replacement) {
    _transaction.edit(begin, end, replacement);
    _mapEditor.edit(begin, end, replacement);
  }

  @override
  SourceFile get file => _transaction.file;

  @override
  bool get hasEdits => _transaction.hasEdits;

  @override
  String get original => _transaction.original;
}

Future<MappedTextEditTransaction> upgradeTransaction(
    TextEditTransaction transaction, Asset originalCss, Asset sourceMap) async {
  var orig = originalCss.readAsString();
  var map = sourceMap.readAsString();
  return new MappedTextEditTransaction(
    transaction,
    new SourceMapEditor(
        basename(sourceMap.id.path),
        parse(await map),
        new PosConverter(await orig),
        new PosConverter(transaction.original)));
}

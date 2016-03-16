// Copyright 2015 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
library scissors.src.source_maps.mapped_text_edit_transaction;

import 'package:source_maps/parser.dart';
import 'package:source_maps/source_maps.dart';
import 'package:source_span/source_span.dart';

import 'package:path/path.dart';
import 'package:barback/barback.dart';
import 'dart:async';

import 'pos_converter.dart';
import 'source_map_editor.dart';

class _MockNestedPrinter implements NestedPrinter {
  final String text;
  final String map;
  _MockNestedPrinter(this.text, this.map);

  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class MappedTextEditTransaction implements TextEditTransaction {
  final TextEditTransaction _transaction;
  final SourceMapEditor _mapEditor;

  MappedTextEditTransaction(this._transaction, this._mapEditor);

  @override
  NestedPrinter commit() {
    var printer = _transaction.commit();
    return new _MockNestedPrinter(printer.text, _mapEditor.createSourceMap());
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

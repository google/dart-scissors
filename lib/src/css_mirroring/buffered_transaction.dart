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
library scissors.src.css_mirroring.buffered_transaction;

import 'package:source_maps/refactor.dart' show TextEditTransaction;

class _Edit {
  final int start, end;
  final String text;
  _Edit(this.start, this.end, this.text);
}

class BufferedTransaction {
  final BufferedTransaction _parentTransaction;
  final TextEditTransaction _textEditTransaction;

  List<_Edit> _edits = <_Edit>[];

  BufferedTransaction._(this._parentTransaction) : _textEditTransaction = null;
  BufferedTransaction(this._textEditTransaction) : _parentTransaction = null;

  BufferedTransaction createSubTransaction() => new BufferedTransaction._(this);

  void edit(int start, int end, String text) =>
      _edits.add(new _Edit(start, end, text));

  void reset() {
    _edits.clear();
  }

  void commit() {
    var parent = _parentTransaction ?? _textEditTransaction;
    for (var edit in _edits) {
      parent.edit(edit.start, edit.end, edit.text);
    }
  }

  get length => _edits.length;
}

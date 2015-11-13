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
library scissors.src.source_maps.pos_converter;

class Pos {
  // 1-based.
  int line, column;
  Pos(this.line, this.column);
}

class PosConverter {
  final String src;
  final _lineOffsets = <int>[];

  static final _rx = new RegExp(r'^.*$');

  PosConverter(this.src) {
    for (var match in _rx.allMatches(src)) {
      _lineOffsets.add(match.start);
    }
  }

  getPos(int offset) {
    // TODO(ochafik): Use binary search;
    int line = 0;
    while (line < _lineOffsets.length - 1 && offset >= _lineOffsets[line + 1]) {
      line++;
    }
    return new Pos(line + 1, offset - _lineOffsets[line] + 1);
  }

  getOffset(Pos pos) {
    return _lineOffsets[pos.line - 1] + pos.column - 1;
  }
}

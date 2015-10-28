library scissors.source_maps.pos_converter;

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
    while (line < _lineOffsets.length -1 && offset >= _lineOffsets[line + 1]) {
      line++;
    }
    return new Pos(line + 1, offset - _lineOffsets[line] + 1);
  }
  getOffset(Pos pos) {
    return _lineOffsets[pos.line - 1] + pos.column - 1;
  }
}

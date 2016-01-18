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
library scissors.src.css_mirroring.entity;

import 'package:csslib/visitor.dart' show Declaration, Directive, TreeNode;

import 'buffered_transaction.dart';

class Entity<T extends TreeNode> {
  final String _source;
  final List<T> _list;
  final int _index;
  final Entity _parent;
  Entity(this._source, this._list, this._index, this._parent);

  T get value => _list[_index];

  void remove(BufferedTransaction trans) {
    trans.edit(_getNodeStart(value), _endOffset, '');
  }

  void prepend(BufferedTransaction trans, String s) {
    var start = _getNodeStart(value);
    trans.edit(start, start, s);
  }

  int get _endOffset {
    var value = this.value;
    if (value is Declaration) {
      return getDeclarationEnd(_source, _list, _index);
    } else {
      /// If it is the last rule of ruleset delete rule till the end of parent which is
      /// document end in case of a toplevel ruleset and is directive end if ruleset is
      /// part of a toplevel directive like @media directive.
      return _index < _list.length - 1
          ? _getNodeStart(_list[_index + 1])
          : _parent?._endOffset ?? _source.length;
    }
  }
}

int _getNodeStart(TreeNode node) {
  if (node is Directive) {
    // The node span start does not include '@' so additional -1 is required.
    return node.span.start.offset - 1;
  }
  return node.span.start.offset;
}

int getDeclarationEnd(String source, List decls, int iDecl) {
  if (iDecl < decls.length - 1) {
    return decls[iDecl + 1].span.start.offset;
  }

  final int fileLength = source.length;
  int fromIndex = decls[iDecl].span.end.offset;
  try {
    while (fromIndex + 1 < fileLength) {
      if (source.substring(fromIndex, fromIndex + 2) == '/*') {
        while (source.substring(fromIndex, fromIndex + 2) != '*/') {
          fromIndex++;
        }
      } else if (source[fromIndex] == '}') {
        return fromIndex;
      }
      fromIndex++;
    }
  } on RangeError catch (_) {
    throw new ArgumentError('Invalid CSS');
  }
  // Case when it doesnot find the end of declaration till file end.
  if (source[fromIndex] == '}') {
    return fromIndex;
  }
  throw new ArgumentError('Declaration end not found');
}

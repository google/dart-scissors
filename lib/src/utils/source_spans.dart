// Copyright 2016 Google Inc. All Rights Reserved.
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
import 'package:analyzer/analyzer.dart' show AstNode;
import 'package:analyzer/src/generated/source.dart' show LineInfo;
import 'package:barback/barback.dart' show Asset;
import 'package:source_span/source_span.dart' show SourceSpan, SourceLocation;
import 'dart:async';

Future<SourceSpan> sourceSpanForNode(
    AstNode node, Asset asset, LineInfo lineInfo) async {
  var content = await asset?.readAsString();
  var id = asset.id;
  var sourceUrl = 'package:${id.package}/${id.path}';

  makeLocation(int offset) {
    var location = lineInfo.getLocation(offset);
    return new SourceLocation(offset,
        sourceUrl: sourceUrl,
        line: location.lineNumber,
        column: location.columnNumber);
  }

  var start = makeLocation(node.beginToken.offset);
  var end = makeLocation(node.endToken.end);
  return new SourceSpan(
      start, end, content?.substring(start.offset, end.offset));
}

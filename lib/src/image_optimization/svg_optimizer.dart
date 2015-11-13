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
library scissors.src.image_optimization.svg_optimizer;

import '../utils/result.dart';

class SvgResult {
  final String content;
  final List<TransformMessage> messages;
  SvgResult(this.content, this.messages);
}

// Note: even with `multiLine: true`, dot doesn't match new lines.
final RegExp _xmlDirectiveRx =
    new RegExp(r'<\?xml(.|\n|\r)*?\?>', multiLine: true);
final RegExp _docTypeRx =
    new RegExp(r'<!DOCTYPE[^\]]*?(\[[^]*\])?>', multiLine: true);
final RegExp _xmlCommentRx = new RegExp(r'<!--(.|\n|\r)*?-->', multiLine: true);
final RegExp _multiSpaceRx = new RegExp(r'\s\s+', multiLine: true);
final RegExp _emptyDefsRx =
    new RegExp(r'<\s*defs\s*>\s*<\s*/\s*defs\s*>', multiLine: true);
final RegExp _xmlSpacePreserveRx =
    new RegExp(r'\s+xml:space\s*=\s*"preserve"', multiLine: true);

final RegExp _xmlNsRx =
    new RegExp(r'\s+xmlns:(\w+)\s*=\s*".*?"', multiLine: true);
final RegExp _attributeNsRx =
    new RegExp(r'\b(\w+):\w+\s*=\s*', multiLine: true);

String optimizeSvg(String content) {
  content = content.replaceAll(_xmlDirectiveRx, '');
  content = content.replaceAll(_docTypeRx, '');
  content = content.replaceAll(_xmlCommentRx, '');
  // print('CONTENT: $content');
  content = content.replaceAll(_xmlSpacePreserveRx, '');
  content = content.replaceAll(_emptyDefsRx, '');

  var potentiallyUsedNamespaces =
      _attributeNsRx.allMatches(content).map((m) => m[1]).toSet();
  content = content.replaceAllMapped(
      _xmlNsRx, (m) => potentiallyUsedNamespaces.contains(m[1]) ? m[0] : '');

  content = content.replaceAll(_multiSpaceRx, ' ');
  content = content.replaceAll('; ', ';');
  content = content.replaceAll(': ', ':');
  content = content.replaceAll('> <', '><');

  return content.trim();
}

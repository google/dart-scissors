library scissors.src.svg_optimizer;

import 'dart:async';
// import 'package:xml/xml.dart';

import 'result.dart';

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

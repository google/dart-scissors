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
library scissors.image_inliner;

import 'dart:async';
import 'dart:io';

import 'package:barback/barback.dart';
import 'package:crypto/crypto.dart';
import 'package:csslib/visitor.dart';
import 'package:csslib/parser.dart';
import 'package:quiver/check.dart';
import 'package:source_maps/refactor.dart';
import 'package:source_span/source_span.dart';

import 'hacks.dart' as hacks;
import 'result.dart' show TransformMessage, TransformResult;

String _unquote(String s) {
  // TODO(ochafik): What about url encode, escapes, etc?
  if (s.startsWith('"')) checkArgument(s.endsWith('"'));
  else {
    checkArgument(s.startsWith("'"));
    checkArgument(s.endsWith("'"));
  }
  return s.substring(1, s.length - 1);
}

class InliningVisitor extends Visitor {
  var _literals = <LiteralTerm>[];
  var urls = <SourceSpan, String>{};

  final String source;
  InliningVisitor(this.source);

  @override
  void visitFunctionTerm(FunctionTerm node) {
    _literals.clear();
    super.visitFunctionTerm(node);
    if (node.value == 'inline-image') {
      checkState(_literals.length == 2 && _literals[0] == node);
      String url = _unquote(_literals.last.value);
      var start = new SourceLocation(
          source.lastIndexOf(node.value, node.span.start.offset),
          sourceUrl: node.span.start.sourceUrl);
      var end = node.span.end;
      var text = source.substring(start.offset, end.offset);
      var span = new SourceSpan(start, end, text);
      urls[span] = url;
    }
  }

  void visitLiteralTerm(LiteralTerm node) {
    _literals.add(node);
  }
}

Future<TransformResult> inlineImages(Asset input,
    {Future<Asset> assetFetcher(String url, {AssetId from})}) async {
  hacks.useCssLib();

  var css = await input.readAsString();
  var cssSourceFile = new SourceFile(css, url: "${input.id}");
  var cssTree = new Parser(cssSourceFile, css).parse();
  var visitor = new InliningVisitor(css);
  cssTree.visit(visitor);

  var transaction = new TextEditTransaction(css, cssSourceFile);

  var messages = <TransformMessage>[];
  var futures = <Future>[];
  visitor.urls.forEach((SourceSpan span, String url) {
    futures.add((() async {
      Asset imageAsset = await assetFetcher(url, from: input.id);
      var dataUrl = await encodeDataAsUri(imageAsset);
      transaction.edit(span.start.offset, span.end.offset, 'url($dataUrl)');
      messages.add(new TransformMessage(LogLevel.INFO,
          "Inlined '$url' with ${imageAsset.id}", input.id, span));
    })());
  });
  await Future.wait(futures);

  if (!transaction.hasEdits) return new TransformResult(false, messages);

  var printer = transaction.commit()..build(input.id.path);
  return new TransformResult(
      true,
      messages,
      new Asset.fromString(input.id, printer.text),
      new Asset.fromString(input.id.addExtension('.map'), printer.map));
}

const _mediaTypeByExtension = const <String, String>{
  '.jpeg': 'image/jpeg',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
};

Future<String> encodeDataAsUri(Asset asset) async {
  var mediaType = _mediaTypeByExtension[asset.id.extension];
  var data = await asset
      .read()
      .fold(new BytesBuilder(), (builder, data) => builder..add(data));
  var encodedData = CryptoUtils.bytesToBase64(data.takeBytes(), urlSafe: true);
  return 'data:$mediaType;base64,$encodedData';
}

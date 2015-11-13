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
library scissors.src.image_inlining.image_inliner;

import 'dart:async';

import 'package:barback/barback.dart';
import 'package:crypto/crypto.dart';
import 'package:csslib/visitor.dart';
import 'package:csslib/parser.dart';
import 'package:quiver/check.dart';
import 'package:source_maps/refactor.dart';
import 'package:source_span/source_span.dart';

import '../utils/hacks.dart' as hacks;
import '../utils/io_utils.dart';
import '../utils/result.dart' show TransformMessage, TransformResult;

enum ImageInliningMode {
  inlineAllUrls,
  inlineInlinedImages,
  linkInlinedImages,
  disablePass
}

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
  var inlineImageUrls = <SourceSpan, String>{};
  var urls = <SourceSpan, String>{};

  final String source;
  InliningVisitor(this.source);

  @override
  void visitUriTerm(UriTerm node) {
    var span = _computeActualSpan(node.span, "url");
    urls[span] = node.text;
  }

  @override
  void visitFunctionTerm(FunctionTerm node) {
    _literals.clear();
    super.visitFunctionTerm(node);
    if (node.value == 'inline-image') {
      checkState(_literals.length == 2 && _literals[0] == node);
      String url = _unquote(_literals.last.value);
      var span = _computeActualSpan(node.span, node.value);
      inlineImageUrls[span] = url;
    }
  }

  void visitLiteralTerm(LiteralTerm node) {
    _literals.add(node);
  }

  SourceSpan _computeActualSpan(SourceSpan span, String startPattern) {
    var start = new SourceLocation(
        source.lastIndexOf(startPattern, span.start.offset),
        sourceUrl: span.start.sourceUrl);
    var end = span.end;
    var text = source.substring(start.offset, end.offset);
    return new SourceSpan(start, end, text);
  }
}

final _urlsRx = new RegExp(r'\b(inline-image|url)\s*\(', multiLine: true);

Future<TransformResult> inlineImages(Asset input, ImageInliningMode mode,
    {Future<Asset> assetFetcher(String url, {AssetId from}),
    String resolveLinkToAsset(Asset asset)}) async {
  var css = await input.readAsString();

  // Fail fast in case there's no url mention in the css.
  if (_urlsRx.firstMatch(css) == null) {
    return new TransformResult(false);
  }

  hacks.useCssLib();

  var cssSourceFile = new SourceFile(css, url: "${input.id}");
  var cssTree = new Parser(cssSourceFile, css).parse();
  var visitor = new InliningVisitor(css);
  cssTree.visit(visitor);

  var messages = <TransformMessage>[];

  Future<String> encodeUrl(SourceSpan span, String url) async {
    Asset imageAsset = await assetFetcher(url, from: input.id);
    messages.add(new TransformMessage(
        LogLevel.INFO, "Inlined '$url' with ${imageAsset.id}", input.id, span));
    return encodeDataAsUri(imageAsset);
  }

  var urlsToInline = <SourceSpan, String>{};
  var urlsToLink = <SourceSpan, String>{};

  switch (mode) {
    case ImageInliningMode.inlineAllUrls:
      urlsToInline = {}..addAll(visitor.inlineImageUrls)..addAll(visitor.urls);
      break;
    case ImageInliningMode.inlineInlinedImages:
      urlsToInline = visitor.inlineImageUrls;
      break;
    case ImageInliningMode.linkInlinedImages:
      urlsToLink = visitor.inlineImageUrls;
      break;
    default:
      throw new StateError("Unsupported: $mode");
  }

  if (urlsToInline.isEmpty && urlsToLink.isEmpty) {
    // We reach here if there was an issue parsing the css...
    return new TransformResult(false, messages);
  }

  var futures = <Future>[];
  var replacements = <SourceSpan, String>{};
  urlsToInline.forEach((SourceSpan span, String url) {
    futures.add((() async {
      var dataUri = await encodeUrl(span, url);
      replacements[span] = "url('$dataUri')";
    })());
  });
  urlsToLink.forEach((SourceSpan span, String url) {
    futures.add((() async {
      var linkedAsset = await assetFetcher(url, from: input.id);
      var packageUrl = resolveLinkToAsset(linkedAsset);
      replacements[span] = "url('$packageUrl')";
    })());
  });
  await Future.wait(futures);

  var transaction = new TextEditTransaction(css, cssSourceFile);
  replacements.forEach((SourceSpan span, String replacement) {
    transaction.edit(span.start.offset, span.end.offset, replacement);
  });
  ;
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
  var data = await readAll(await asset.read());
  var encodedData = CryptoUtils.bytesToBase64(data, urlSafe: false);
  return 'data:$mediaType;base64,$encodedData';
}

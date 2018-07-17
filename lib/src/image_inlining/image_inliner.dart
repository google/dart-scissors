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
import 'dart:convert';

import 'package:barback/barback.dart';
import 'package:source_maps/refactor.dart';
import 'package:source_span/source_span.dart';

import '../utils/io_utils.dart';
import '../utils/result.dart' show TransformMessage, TransformResult;

enum ImageInliningMode {
  inlineAllUrls,
  inlineInlinedImages,
  linkInlinedImages,
  disablePass
}

final _urlsRx = new RegExp(
    '\\b(inline-image|url)\\s*\\(\\s*["\']([^"\']+)["\']\\s*\\)',
    multiLine: true);

Future<TransformResult> inlineImages(Asset input, ImageInliningMode mode,
    {Future<Asset> assetFetcher(String url, {AssetId from}),
    String resolveLinkToAsset(Asset asset)}) async {
  if (mode == ImageInliningMode.disablePass) {
    return new TransformResult(true);
  }
  final css = await input.readAsString();
  final cssUrl = "${input.id}";
  final cssSourceFile = new SourceFile.fromString(css, url: cssUrl);

  final messages = <TransformMessage>[];

  Future<String> encodeUrl(SourceSpan span, String url) async {
    Asset imageAsset = await assetFetcher(url, from: input.id);
    messages.add(new TransformMessage(
        LogLevel.INFO, "Inlined '$url' with ${imageAsset.id}", input.id, span));
    return encodeAssetAsUri(imageAsset);
  }

  final urlsToInline = <SourceSpan, String>{};
  final urlsToLink = <SourceSpan, String>{};

  for (final match in _urlsRx.allMatches(css)) {
    final kind = match.group(1);
    var url = match.group(2);
    if (url.startsWith('/')) url = url.substring(1);
    final start = new SourceLocation(match.start, sourceUrl: cssUrl);
    final end = new SourceLocation(match.end, sourceUrl: cssUrl);
    final span = new SourceSpan(start, end, match.group(0));

    switch (mode) {
      case ImageInliningMode.inlineAllUrls:
        urlsToInline[span] = url;
        break;
      case ImageInliningMode.inlineInlinedImages:
        if (kind == 'inline-image') urlsToInline[span] = url;
        break;
      case ImageInliningMode.linkInlinedImages:
        if (kind == 'inline-image') urlsToLink[span] = url;
        break;
      default:
        throw new StateError("Unsupported: $mode");
    }
  }

  if (urlsToInline.isEmpty && urlsToLink.isEmpty) {
    return new TransformResult(true);
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

  final transaction = new TextEditTransaction(css, cssSourceFile);
  replacements.forEach((SourceSpan span, String replacement) {
    transaction.edit(span.start.offset, span.end.offset, replacement);
  });

  var printer = transaction.commit()..build(input.id.path);

  return new TransformResult(
      true,
      messages,
      new Asset.fromString(input.id, printer.text),
      new Asset.fromString(input.id.addExtension('.map'), printer.map));
}

const imageMediaTypeByExtension = const <String, String>{
  '.gif': 'image/gif',
  '.jpeg': 'image/jpeg',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
};

Future<String> encodeAssetAsUri(Asset asset) async {
  return encodeBytesAsDataUri(await readAll(asset.read()),
      mimeType: imageMediaTypeByExtension[asset.id.extension]);
}

String encodeBytesAsDataUri(List<int> bytes,
    {String mimeType: "application/octet-stream"}) {
  var encodedData = base64.encode(bytes);
  return 'data:$mimeType;base64,$encodedData';
}

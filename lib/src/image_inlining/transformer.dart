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
library scissors.src.image_inlining.transformer;

import 'dart:async';

import 'package:barback/barback.dart';
import 'package:path/path.dart';
import 'package:quiver/check.dart';

import '../image_inlining/image_inliner.dart';
import '../utils/path_resolver.dart';
import '../utils/settings_base.dart';
import '../utils/enum_parser.dart';

part 'settings.dart';

class ImageInliningTransformer extends Transformer implements DeclaringTransformer {
  final ImageInliningSettings settings;

  ImageInliningTransformer(this.settings);
  ImageInliningTransformer.asPlugin(BarbackSettings settings)
      : this(new _ImageInliningSettings.fromSettings(settings));

  bool get _isDisabled =>
      settings.imageInlining.value == ImageInliningMode.disablePass;

  @override String get allowedExtensions =>
      _isDisabled ? ".no-such-extension" : ".css .css.map";

  final RegExp _filesToSkipRx =
      new RegExp(r'^_.*?\.scss|.*?\.ess\.s[ac]ss\.css(\.map)?$');

  bool _shouldSkipAsset(AssetId id) {
    var name = basename(id.path);
    return _filesToSkipRx.matchAsPrefix(name) != null;
  }

  @override
  declareOutputs(DeclaringTransform transform) {
    if (_isDisabled) return;

    var id = transform.primaryId;
    if (_shouldSkipAsset(id)) return;

    transform.declareOutput(id);
    transform.declareOutput(id.addExtension('.map'));
  }

  Future apply(Transform transform) async {
    if (_isDisabled) return;

    var cssAsset = transform.primaryInput;

    if (_shouldSkipAsset(cssAsset.id)) {
      transform.logger.info("Skipping ${transform.primaryInput.id}");
      return;
    }

    var rewritePackage =
        _getPackageRewriter(settings.packageRewrites.value);

    var result = await inlineImages(
        cssAsset, settings.imageInlining.value,
        assetFetcher: (String url, {AssetId from}) {
      return pathResolver.resolveAsset(transform, [url], from);
    }, resolveLinkToAsset: (Asset asset) {
      var uri = pathResolver.assetIdToUri(asset.id);
      return rewritePackage(uri);
    });
    result.logMessages(transform);
    if (result.success) {
      transform.addOutput(result.css);
      if (result.map != null) transform.addOutput(result.map);
    }
  }
}

Function _getPackageRewriter(String fromToString) {
  var fromTo = fromToString.split(',');
  checkState(fromTo.length == 2,
      message: () => "Expected from,to pattern, got: $fromToString");
  var fromRx = new RegExp(fromTo[0]);
  var to = fromTo[1];
  return (String s) => s.replaceFirst(fromRx, to);
}

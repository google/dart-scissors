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
library scissors.image_inliner_transformer;

import 'dart:async';

import 'package:barback/barback.dart';

import 'blacklists.dart';
import 'image_inliner.dart';
import 'path_resolver.dart';
import 'settings.dart';

/// sCiSSors is an Angular tree-shaker for CSS files.
/// It drops CSS rule sets that are not referenced from Angular templates.
class ScissorsImageInlinerTransformer extends Transformer {
  final ScissorsSettings settings;

  ScissorsImageInlinerTransformer(this.settings);

  @override
  String get allowedExtensions => ".css .css.map";

  Future apply(Transform transform) async {
    if (shouldSkipPrimaryAsset(transform, settings)) return null;

    if (transform.primaryInput.id.path.endsWith(".map")) {
      // transform.consumePrimary();
      return null;
    }

    var cssAsset = transform.primaryInput;
    var cssId = cssAsset.id;


    // We failed to load the converted result, so run sassc ourselves.
    var stopwatch = new Stopwatch()..start();
    var result = await inlineImages(cssAsset, assetFetcher: (String url, {AssetId from}) {
      return resolveAsset(transform, url, from);
    });
    transform.logger.info('Inlining images in $cssId took ${stopwatch.elapsed.inMilliseconds} msec.');
    result.logMessages(transform);

    if (result.success) {
      transform.addOutput(result.css);
      // transform.addOutput(result.map);
    }
  }
}

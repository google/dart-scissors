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
library scissors.scissors_transformer;

import 'dart:async';

import 'package:barback/barback.dart';

import 'package:quiver/check.dart';

import 'settings.dart';
import 'svg_optimizer.dart';
import 'png_optimizer.dart';

class ImageOptimizationTransformer extends Transformer
    implements DeclaringTransformer {
  final ScissorsSettings settings;

  @override
  final String allowedExtensions;
  ImageOptimizationTransformer(this.settings, this.allowedExtensions);

  @override
  declareOutputs(DeclaringTransform transform) {
    transform.consumePrimary();
    transform.declareOutput(transform.primaryId);
  }

  Future _optimizeSvg(Transform transform, Asset asset) async {
    String input = await asset.readAsString();
    String output = optimizeSvg(input);
    transform.addOutput(new Asset.fromString(asset.id, output));
    transform.logger.info(
        'Optimized SVG: ${input.length} chars -> ${output.length} chars',
        asset: asset.id);
    if (settings.verbose.value) {
      transform.logger.info('Optimized SVG content:\n$output', asset: asset.id);
    }
  }

  Future _optimizePng(Transform transform, Asset asset) async {
    int originalSize;
    int resultSize;
    transform.addOutput(await crushPng(asset, (int a, int b) {
      originalSize = a;
      resultSize = b;
    }));
    transform.logger.info(
        'Optimized PNG: ${originalSize} bytes -> ${resultSize} bytes',
        asset: asset.id);
    ;
  }

  Future apply(Transform transform) async {
    var id = transform.primaryInput.id;

    transform.consumePrimary();
    switch (id.extension) {
      case '.svg':
        checkState(settings.optimizeSvg.value);
        await _optimizeSvg(transform, transform.primaryInput);
        break;
      case '.png':
        checkState(settings.optimizePng.value);
        await _optimizePng(transform, transform.primaryInput);
        break;
    }
  }
}

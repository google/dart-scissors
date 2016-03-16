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
library scissors.src.png_optimization.transformer;

import 'dart:async';

import 'package:barback/barback.dart';

import '../utils/path_resolver.dart';
import '../utils/settings_base.dart';
import '../utils/delta_format.dart';
import 'pngcrush_runner.dart';

part 'settings.dart';

class PngOptimizationTransformer extends Transformer
    implements DeclaringTransformer {
  final PngOptimizationSettings _settings;

  PngOptimizationTransformer(this._settings);
  PngOptimizationTransformer.asPlugin(BarbackSettings settings)
      : this(new _PngOptimizationSettings(settings));

  @override
  final String allowedExtensions = ".png";

  @override
  bool isPrimary(AssetId id) =>
      _settings.optimizePng.value && super.isPrimary(id);

  @override
  declareOutputs(DeclaringTransform transform) {
    // transform.consumePrimary();
    transform.declareOutput(transform.primaryId);
  }

  Future apply(Transform transform) async {
    int originalSize;
    int resultSize;
    transform.addOutput(await runPngCrush(
        await _settings.pngCrushPath.value, transform.primaryInput,
        (int a, int b) {
      originalSize = a;
      resultSize = b;
    }));
    transform.logger
        .info('Optimized PNG: ${formatDeltaBytes(originalSize, resultSize)}');
  }
}

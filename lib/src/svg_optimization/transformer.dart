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
library scissors.src.image_optimization_transformer.image_optimization_transformer;

import 'dart:async';

import 'package:barback/barback.dart';

import '../utils/delta_format.dart';
import '../utils/settings_base.dart';
import 'svg_optimizer.dart';

abstract class SvgOptimizationSettings {
  Setting<bool> get verbose;

  final optimizeSvg = makeOptimSetting('optimizeSvg');
}

class _SvgOptimizationSettings extends SettingsBase
    with SvgOptimizationSettings {
  _SvgOptimizationSettings(settings) : super(settings);
}

class SvgOptimizationTransformer extends Transformer
    implements DeclaringTransformer {
  final SvgOptimizationSettings settings;

  SvgOptimizationTransformer(this.settings);
  SvgOptimizationTransformer.asPlugin(BarbackSettings settings)
      : this(new _SvgOptimizationSettings(settings));

  @override
  final String allowedExtensions = ".svg";

  @override
  bool isPrimary(AssetId id) =>
      settings.optimizeSvg.value && super.isPrimary(id);

  @override
  declareOutputs(DeclaringTransform transform) {
    // transform.consumePrimary();
    transform.declareOutput(transform.primaryId);
  }

  Future apply(Transform transform) async {
    var asset = transform.primaryInput;
    String input = await asset.readAsString();
    String output = optimizeSvg(input);
    transform.addOutput(new Asset.fromString(asset.id, output));
    transform.logger.info(
        'Optimized SVG: ${formatDeltaChars(input.length, output.length)}',
        asset: asset.id);
    if (settings.verbose.value) {
      transform.logger.info('Optimized SVG content:\n$output', asset: asset.id);
    }
  }
}

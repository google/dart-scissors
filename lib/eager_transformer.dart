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

import 'package:barback/barback.dart';

import 'src/css_mirroring/transformer.dart';
import 'src/css_pruning/transformer.dart';
import 'src/image_inlining/transformer.dart';
import 'src/png_optimization/transformer.dart';
import 'src/sass/transformer.dart';
import 'src/svg_optimization/transformer.dart';
import 'src/utils/phase_utils.dart';
import 'src/utils/settings_base.dart';

class _ScissorsSettings extends SettingsBase
    with
        SvgOptimizationSettings,
        PngOptimizationSettings,
        SassSettings,
        CssPruningSettings,
        CssMirroringSettings,
        ImageInliningSettings {
  _ScissorsSettings(BarbackSettings settings) : super(settings);
}

List<List<Transformer>> _createPhases(_ScissorsSettings settings) {
  var phases = [
    [
      settings.optimizeSvg.value
          ? new SvgOptimizationTransformer(settings)
          : null,
      settings.optimizePng.value
          ? new PngOptimizationTransformer(settings)
          : null,
      settings.compileSass.value ? new SassTransformer(settings) : null
    ],
    [settings.pruneCss.value ? new CssPruningTransformer(settings) : null],
    [
      settings.imageInlining.value != ImageInliningMode.disablePass
          ? new ImageInliningTransformer(settings)
          : null
    ],
    [settings.mirrorCss.value ? new CssMirroringTransformer(settings) : null],
  ];
  return trimPhases(phases);
}

class EagerScissorsTransformerGroup extends TransformerGroup {
  EagerScissorsTransformerGroup(_ScissorsSettings settings)
      : super(_createPhases(settings));

  EagerScissorsTransformerGroup.asPlugin(BarbackSettings settings)
      : this(new _ScissorsSettings(settings));
}

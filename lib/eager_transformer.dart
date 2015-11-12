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

import 'src/image_inliner.dart';
import 'src/settings.dart';
import 'src/image_optimization_transformer.dart';
import 'src/sass_and_css_pruning_transformer.dart';

List<List<Transformer>> _createPhases(ScissorsSettings settings) {
  var phases = <List<Transformer>>[];
  var imageExts = [];
  if (settings.optimizePng.value) imageExts.add('.png');
  if (settings.optimizeSvg.value) imageExts.add('.svg');
  if (imageExts.isNotEmpty) {
    phases
        .add([new ImageOptimizationTransformer(settings, imageExts.join(' '))]);
  }

  var exts = [];
  if (settings.compileSass.value) exts..add('.sass')..add('.scss');
  if (settings.pruneCss.value ||
      settings.imageInlining != ImageInliningMode.disablePass) {
    exts..add('.css')..add('.map');
  }
  if (exts.isNotEmpty) {
    phases.add([new SassAndCssPruningTransformer(settings, exts.join(' '))]);
  }
  return phases;
}

class EagerScissorsTransformerGroup extends TransformerGroup {
  EagerScissorsTransformerGroup(ScissorsSettings settings)
      : super(_createPhases(settings));

  EagerScissorsTransformerGroup.asPlugin(BarbackSettings settings)
      : this(new ScissorsSettings.fromSettings(settings));
}

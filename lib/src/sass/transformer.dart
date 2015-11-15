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
library scissors.src.sass.sass_and_css_pruning_transformer;

import 'dart:async';

import 'package:barback/barback.dart';

import '../utils/deps_consumer.dart';
import '../utils/settings_base.dart';
import 'sassc_runner.dart' show SasscSettings, runSassC;
import 'package:scissors/src/utils/path_resolver.dart';

part 'settings.dart';

class SassTransformer extends Transformer implements DeclaringTransformer {
  final SassSettings _settings;

  SassTransformer(this._settings);
  SassTransformer.asPlugin(BarbackSettings settings)
      : this(new _SassSettings(settings));

  @override final String allowedExtensions = ".sass .scss";

  @override bool isPrimary(AssetId id) =>
      _settings.compileSass.value && super.isPrimary(id);

  @override
  declareOutputs(DeclaringTransform transform) {
    if (!_settings.isDebug) transform.consumePrimary();

    var id = transform.primaryId;
    transform.declareOutput(id.addExtension('.css'));
    transform.declareOutput(id.addExtension('.css.map'));
  }

  Future apply(Transform transform) async {
    var scss = transform.primaryInput;

    // Mark transitive SASS @imports as barback dependencies.
    var depsConsumption = consumeTransitiveSassDeps(transform, scss);

    var result = await runSassC(scss,
        isDebug: _settings.isDebug, settings: await _settings.sasscSettings);
    result.logMessages(transform);

    await depsConsumption;

    if (!result.success) return null;

    if (!_settings.isDebug) transform.consumePrimary();
    transform.addOutput(result.css);
    if (result.map != null) transform.addOutput(result.map);
  }
}

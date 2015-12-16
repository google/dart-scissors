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
library scissors.mirroring_transformer;

import 'package:barback/barback.dart';

import 'src/css_mirroring/transformer.dart';
import 'src/js_optimization/settings.dart';
import 'src/parts_check/transformer.dart';
import 'src/utils/settings_base.dart';

/// This transformer perform rtl css mirroring.
class CssMirroringTransformerGroup extends TransformerGroup {
  final CssMirroringSettings _settings;

  CssMirroringTransformerGroup(_CssMirroringGroupSettings settings)
      : super([
          [
            new CssMirroringTransformer(settings)
          ]
        ]),
        _settings = settings;

  CssMirroringTransformerGroup.asPlugin(BarbackSettings settings)
      : this(new _CssMirroringGroupSettings(settings));
}

class _CssMirroringGroupSettings extends SettingsBase
    with CssMirroringSettings, PartsCheckSettings, JsOptimizationSettings {
  _CssMirroringGroupSettings(settings) : super(settings);
}

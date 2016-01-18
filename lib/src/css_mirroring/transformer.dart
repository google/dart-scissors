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
library scissors.src.css_mirroring.transformer;

import 'dart:async';

import 'package:barback/barback.dart';

import 'bidi_css_generator.dart';
import 'cssjanus_runner.dart';
import 'edit_configuration.dart';
import '../utils/enum_parser.dart';
import '../utils/file_skipping.dart';
import '../utils/path_resolver.dart';
import '../utils/settings_base.dart';

part 'settings.dart';

class CssMirroringTransformer extends Transformer
    implements DeclaringTransformer {
  final CssMirroringSettings _settings;

  CssMirroringTransformer(this._settings);

  CssMirroringTransformer.asPlugin(BarbackSettings settings)
      : this(new _CssMirroringSettings(settings));

  @override String get allowedExtensions => '.css .css.map';

  @override bool isPrimary(AssetId id) =>
      _settings.mirrorCss.value && super.isPrimary(id);

  @override
  declareOutputs(DeclaringTransform transform) {
    var id = transform.primaryId;
    if (shouldSkipAsset(id)) return;

    if (id.extension == '.map') {
      // The transformer converts input css to new bidi css so the input
      // .css.map will no longer be valid.
      transform.consumePrimary();
    } else {
      transform.declareOutput(id);
    }
  }

  Future apply(Transform transform) async {
    if (transform.primaryInput.id.extension == '.map') {
      transform.consumePrimary();
      return;
    }
    var cssAsset = transform.primaryInput;
    if (shouldSkipAsset(cssAsset.id)) {
      transform.logger.info('Skipping ${transform.primaryInput.id}');
      return;
    }

    /// Read original source css.
    var source = await cssAsset.readAsString();

    var generator = await BidiCssGenerator.build(
        source, cssAsset.id.toString(), _settings.nativeDirection.value,
        (String css) async {
      return await runCssJanus(css, await _settings.cssJanusPath.value);
    });
    var output = generator.getOutputCss();
    if (_settings.verbose.value) transform.logger.info(output);
    transform.addOutput(new Asset.fromString(cssAsset.id, output));
  }
}

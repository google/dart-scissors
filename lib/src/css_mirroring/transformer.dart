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
import 'css_utils.dart' show Direction;
import '../utils/enum_parser.dart';
import '../utils/file_skipping.dart';
import '../utils/path_resolver.dart';
import '../utils/settings_base.dart';

part 'settings.dart';

final _primaryRx = new RegExp(r'^(.*?)\.css(?:\.map)?');

class BidiCssTransformer extends AggregateTransformer
    implements DeclaringAggregateTransformer {
  final CssMirroringSettings _settings;

  BidiCssTransformer(this._settings);

  BidiCssTransformer.asPlugin(BarbackSettings settings)
      : this(new _CssMirroringSettings(settings));

  // @override String get allowedExtensions => '.css .css.map';

  @override
  classifyPrimary(AssetId id) => !_settings.bidiCss.value || shouldSkipAsset(id)
      ? null
      : _primaryRx.matchAsPrefix(id.toString())?.group(1);

  @override
  declareOutputs(DeclaringAggregateTransform transform) async {
    var ids = await transform.primaryIds.toList();
    var cssId =
        ids.firstWhere((id) => id.extension == '.css', orElse: () => null);
    var mapId =
        ids.firstWhere((id) => id.extension == '.map', orElse: () => null);
    if (cssId == null) return;
    if (shouldSkipAsset(cssId)) return;

    if (mapId != null) transform.consumePrimary(mapId);
    if (cssId != null) transform.declareOutput(cssId);
  }

  Future apply(AggregateTransform transform) async {
    var inputs = await transform.primaryInputs.toList();
    var cssAsset = inputs.firstWhere((asset) => asset.id.extension == '.css',
        orElse: () => null);
    var mapAsset = inputs.firstWhere((asset) => asset.id.extension == '.map',
        orElse: () => null);
    if (cssAsset == null) return;
    if (shouldSkipAsset(cssAsset.id)) {
      transform.logger.info('Skipping ${cssAsset.id}');
      return;
    }

    if (mapAsset != null) transform.consumePrimary(mapAsset.id);

    var bidiCss = await bidirectionalizeCss(await cssAsset.readAsString(),
        _flipCss, _settings.originalCssDirection.value);
    if (_settings.verbose.value) {
      transform.logger.info('Bidirectionalized css:\n$bidiCss');
    }
    transform.addOutput(new Asset.fromString(cssAsset.id, bidiCss));
  }

  Future<String> _flipCss(String css) async =>
      runCssJanus(css, await _settings.cssJanusPath.value);
}

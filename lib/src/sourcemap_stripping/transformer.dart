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
library scissors.src.sourcemap_stripping.transformer;

import 'package:barback/barback.dart';

import '../utils/settings_base.dart';
import 'package:scissors/src/sourcemap_stripping/sourcemap_stripping.dart';

part 'settings.dart';

/// Drops any sourceMappingURL reference from .js files, to avoid 404s in prod.
class SourcemapStrippingTransformer extends Transformer
    implements LazyTransformer {
  final SourcemapStrippingSettings _settings;

  SourcemapStrippingTransformer(this._settings);
  SourcemapStrippingTransformer.asPlugin(BarbackSettings settings)
      : this(new _SourcemapStrippingSettings(settings));

  @override
  String get allowedExtensions => ".js";

  @override
  declareOutputs(DeclaringTransform transform) {
    if (!_settings.stripSourceMaps.value) return;
    transform.declareOutput(transform.primaryId);
  }

  apply(Transform transform) async {
    if (!_settings.stripSourceMaps.value) return;

    final id = transform.primaryInput.id;
    final js = await transform.primaryInput.readAsString();

    final strippedJs = stripSourcemap(js, (url) {
      transform.logger.info("Stripped sourcemap URL: '$url'", asset: id);
    });
    transform.addOutput(new Asset.fromString(id, strippedJs));
  }
}

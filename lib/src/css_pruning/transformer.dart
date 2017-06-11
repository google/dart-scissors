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
library scissors.src.css_pruning.transformer;

import 'dart:async';

import 'package:barback/barback.dart';
import 'package:source_maps/refactor.dart';
import 'package:source_span/source_span.dart';

import '../utils/settings_base.dart';
import '../utils/file_skipping.dart';
import '../utils/delta_format.dart';
import 'css_pruning.dart';

part 'settings.dart';

class CssPruningTransformer extends Transformer
    implements DeclaringTransformer {
  final CssPruningSettings _settings;

  CssPruningTransformer(this._settings);
  CssPruningTransformer.asPlugin(BarbackSettings settings)
      : this(new _CssPruningSettings(settings));

  @override
  final String allowedExtensions = ".css .css.map";

  @override
  bool isPrimary(AssetId id) => _settings.pruneCss.value && super.isPrimary(id);

  @override
  declareOutputs(DeclaringTransform transform) {
    var id = transform.primaryId;
    if (shouldSkipAsset(id)) return;

    if (id.extension == '.map') {
      transform.consumePrimary();
    } else {
      transform.declareOutput(id.addExtension('.css'));
      transform.declareOutput(id.addExtension('.css.map'));
    }
  }

  Future apply(Transform transform) async {
    if (transform.primaryInput.id.extension == '.map') {
      transform.consumePrimary();
      return;
    }
    var cssAsset = transform.primaryInput;
    if (shouldSkipAsset(cssAsset.id)) {
      transform.logger.info("Skipping ${transform.primaryInput.id}");
      return;
    }

    try {
      String htmlTemplate = await findHtmlTemplate(transform, cssAsset.id);

      var source = await cssAsset.readAsString();
      var sourceFile =
          new SourceFile.fromString(source, url: cssAsset.id.toString());

      var transaction = new TextEditTransaction(source, sourceFile);
      dropUnusedCssRules(
          transform, transaction, _settings, sourceFile, htmlTemplate);

      if (transaction.hasEdits) {
        var printer = transaction.commit()..build(cssAsset.id.path);
        var result = printer.text;
        // TODO(ochafik): Better stats / reporting (delta + %).
        transform.logger.info(
            "Pruned CSS: ${formatDeltaChars(source.length, result.length)}",
            asset: cssAsset.id);

        transform.consumePrimary();
        transform.addOutput(new Asset.fromString(cssAsset.id, result));
        transform.addOutput(new Asset.fromString(
            cssAsset.id.addExtension('.map'), printer.map));
      }
    } on AssetNotFoundException catch (_) {
      // No HTML template found: leave the CSS alone!
    }
  }
}

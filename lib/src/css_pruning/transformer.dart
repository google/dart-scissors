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
import 'package:path/path.dart';
import 'package:source_maps/refactor.dart';
import 'package:source_span/source_span.dart';

import 'css_pruning.dart';
import '../utils/path_utils.dart';
import '../utils/settings_base.dart';
import '../utils/settings_base.dart';

part 'settings.dart';

class CssPruningTransformer extends Transformer
    implements DeclaringTransformer {
  final CssPruningSettings settings;

  CssPruningTransformer(this.settings);
  CssPruningTransformer.asPlugin(BarbackSettings settings)
      : this(new _CssPruningSettings(settings));

  @override String get allowedExtensions =>
      settings.pruneCss.value ? ".css .css.map" : "";

  final RegExp _filesToSkipRx =
      new RegExp(r'^_.*?\.scss|.*?\.ess\.s[ac]ss\.css(\.map)?$');

  bool _shouldSkipAsset(AssetId id) {
    var name = basename(id.path);
    return _filesToSkipRx.matchAsPrefix(name) != null;
  }

  @override
  declareOutputs(DeclaringTransform transform) {
    var id = transform.primaryId;
    if (_shouldSkipAsset(id)) return;

    transform.consumePrimary();
    transform.declareOutput(id.addExtension('.css'));
    transform.declareOutput(id.addExtension('.css.map'));
  }

  Future apply(Transform transform) async {
    var cssAsset = transform.primaryInput;
    if (_shouldSkipAsset(cssAsset.id)) {
      transform.logger.info("Skipping ${transform.primaryInput.id}");
      return;
    }

    try {
      String htmlTemplate = await findHtmlTemplate(transform, cssAsset.id);

      var source = await cssAsset.readAsString();
      var sourceFile = new SourceFile(source, url: cssAsset.id.toString());

      var transaction = new TextEditTransaction(source, sourceFile);
      dropUnusedCssRules(
          transform, transaction, settings, sourceFile, htmlTemplate);

      if (transaction.hasEdits) {
        var printer = transaction.commit()..build(cssAsset.id.path);
        // TODO(ochafik): Better stats / reporting (delta + %).
        transform.logger.info("Size[${cssAsset.id}]: "
            "before = ${source.length}, after = ${printer.text.length}");

        transform.consumePrimary();
        transform.addOutput(new Asset.fromString(cssAsset.id, printer.text));
        transform.addOutput(new Asset.fromString(
            cssAsset.id.addExtension('.map'), printer.map));
      }
    } catch (e, s) {
      acceptAssetNotFoundException(e, s);
      // No HTML template found: leave the CSS alone!
    }
  }
}

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
import 'package:source_maps/refactor.dart';
import 'package:source_span/source_span.dart';

import '../utils/path_resolver.dart';
import '../utils/path_utils.dart';
import '../utils/settings_base.dart';
import '../utils/file_skipping.dart';
import '../utils/delta_format.dart';
import '../utils/io_utils.dart';
import 'dart:io';
import 'dart:convert';

import 'rtl_convertor.dart';

part 'settings.dart';

class CssMirroringTransformer extends Transformer
    implements DeclaringTransformer {
  final CssMirroringSettings _settings;

  CssMirroringTransformer(this._settings);
  CssMirroringTransformer.asPlugin(BarbackSettings settings)
      : this(new _CssMirroringSettings(settings));

  @override final String allowedExtensions = ".css .css.map";

  @override bool isPrimary(AssetId id) =>
      _settings.mirrorCss.value && super.isPrimary(id);

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

      var source = await cssAsset.readAsString();
      var sourceFile = new SourceFile(source, url: cssAsset.id.toString());
      var transaction = new TextEditTransaction(source, sourceFile);

      var cssJanusPath = _settings.cssJanusPath.value;
      Process process = await Process.start('python', [cssJanusPath]);
      cssAsset.read().pipe(process.stdin);
      var out = readAll(process.stdout);
      var err = readAll(process.stderr);
      var source1;
      if ((await process.exitCode ?? 0) != 0) {
        var errStr = new Utf8Decoder().convert(await err);
        throw new ArgumentError(
            'Failed to run Closure Compiler (exit code = ${await process.exitCode}):\n$errStr');
      }
     else {
        source1 = new Utf8Decoder().convert(await out);
      }

      var sourceFile1 = new SourceFile(source1, url: cssAsset.id.toString());
      var transaction1 = new TextEditTransaction(source1, sourceFile1);
      var transaction2 = new TextEditTransaction(source1, sourceFile1);

      generatecommon(transform, transaction, transaction1, transaction2, _settings, sourceFile, sourceFile1, sourceFile1);
      if (transaction2.hasEdits) {
        var printer = transaction2.commit()..build(cssAsset.id.path);
        var result = printer.text;
        // TODO(ochafik): Better stats / reporting (delta + %).
//        transform.logger.info(
//            "Mirrored CSS: ${formatDeltaChars(source.length, result.length)}",
//            asset: cssAsset.id);

        result = result + '\n' + (transaction.commit()..build('')).text;
        result = result + '\n' + (transaction1.commit()..build('')).text;
        print(result);
        transform.consumePrimary();
        transform.addOutput(new Asset.fromString(cssAsset.id, result));
        transform.addOutput(new Asset.fromString(
            cssAsset.id.addExtension('.map'), printer.map));
      }
    } catch (e, s) {
      acceptAssetNotFoundException(e, s);
      // No HTML template found: leave the CSS alone!
    }
  }
}

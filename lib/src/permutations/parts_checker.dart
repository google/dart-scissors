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
library scissors.src.permutations.transformer;

import 'package:barback/barback.dart';

import '../settings.dart';

/// This transformer stitches deferred message parts together in pre-assembled
/// .js artefact permutations, to speed up initial loading of pages.
///
/// It must be run *after* the $dart2js transformer, and $dart2js must have the
/// a `--deferred-map=something` parameter
/// (see `example/permutations/pubspec.yaml`).
///
/// For instance if `main.dart.js` defer-loads messages for locales `en` and
/// `fr`, this transformer will create the artefact `main_en.js` (still able
/// to defer-load the `fr` locale, but with instant loading of locale `en`) and
/// `main_fr.js` (the opposite).
///
/// This lives in sCiSSors so that additional optimizations can be performed on
/// the stitched output, for instance running Closure Compiler in SIMPLE mode
/// on the resulting stitched output saves 10% of raw size in
/// example/permutations/build/web/main_en.js (85kB -> 76kB), and still
/// 1kB / 24kB in gzipped size.
///
/// cat example/permutations/build/web/main_en.js | gzip -9 | wc -c
/// cat example/permutations/build/web/main_en.js | java -jar compiler.jar --language_in=ES5 --language_out=ES5 -O SIMPLE | gzip -9 | wc -c
///
/// This might interact with the CSS mirroring feature, in ways still TBD.
///
class PartsCheckTransformer extends Transformer
    implements DeclaringTransformer {
  final ScissorsSettings _settings;

  PartsCheckTransformer(this._settings);

  PartsCheckTransformer.asPlugin(BarbackSettings settings)
      : this(new ScissorsSettings.fromSettings(settings));

  @override String get allowedExtensions =>
      expectedPartCounts.isEmpty ? "" : ".dart.js";

  get expectedPartCounts => _settings.expectedPartCounts.value;

  @override
  apply(Transform transform) async {
    //var main basename(transform.id.path).replace('.dart.js', '');
    var id = transform.primaryInput.id;

    var expectedPartCount = expectedPartCounts[id.path];
    if (expectedPartCount == null) {
      transform.logger.error("No part count expectation set for ${id.path}");
      return;
    }
    int count = 0;
    while (true) {
      try {
        var partId = id.addExtension("_${count + 1}.part.js");
        await transform.getInput(partId);
        count++;
      } catch (_) {
        break;
      }
    }
    if (count == expectedPartCount) {
      transform.logger.info("Found $count part files, as expected.", asset: id);
    } else {
      transform.logger.error(
          "Found $count part files, but expected $expectedPartCount !!!",
          asset: id);
    }
  }

  @override
  declareOutputs(DeclaringTransform transform) {
    // No output to declare.
  }
}

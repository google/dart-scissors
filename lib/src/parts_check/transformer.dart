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
library scissors.src.parts_check.transformer;

import 'package:barback/barback.dart';

import '../utils/settings_base.dart';

part 'settings.dart';

/// Checks that the number of parts for each binary is exactly the one expected.
///
/// Example:
///   transformers:
///   - scissors/src/permutations/parts_checker
///       expectedPartCounts:
///           web/main.dart.js: 6
///
class PartsCheckTransformer extends Transformer
    implements DeclaringTransformer {
  final PartsCheckSettings _settings;

  PartsCheckTransformer(this._settings);
  PartsCheckTransformer.asPlugin(BarbackSettings settings)
      : this(new _PartsCheckSettings(settings));

  @override
  final String allowedExtensions = ".dart.js";

  @override
  bool isPrimary(AssetId id) =>
      expectedPartCounts.isNotEmpty && super.isPrimary(id);

  Map<String, int> get expectedPartCounts =>
      _settings.expectedPartCounts.value as Map<String, int>;

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
    final always = true; // Defeat buggy dead-code warning.
    while (always) {
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
      transform.consumePrimary();
    }
  }

  @override
  declareOutputs(DeclaringTransform transform) {
    // No output to declare.
  }
}

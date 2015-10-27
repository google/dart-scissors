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
library scissors.sass_transformer;

import 'dart:async';

import 'package:barback/barback.dart';
import 'package:path/path.dart';

import 'sassc.dart' show runSassC;
import 'settings.dart';

/// sCiSSors is an Angular tree-shaker for CSS files.
/// It drops CSS rule sets that are not referenced from Angular templates.
class ScissorsSassTransformer extends Transformer {
  final ScissorsSettings settings;

  ScissorsSassTransformer(this.settings);

  @override
  String get allowedExtensions => ".scss .sass";

  static final RegExp _scssFilesToSkipRx = new RegExp(r'^_.*|.*?\.ess\.s[ac]ss$');

  Future apply(Transform transform) async {
    var sassAsset = transform.primaryInput;
    var sassId = sassAsset.id;

    if (_scssFilesToSkipRx.matchAsPrefix(basename(sassId.path)) != null) {
      if (settings.isVerbose) {
        transform.logger.info("Skipping $sassId");
      }
      return new Future.value();
    }

    try {
      // We only run sassc on files that haven't been converted already:
      // Try and load the converted result first.
      await transform.getInput(
          sassId.changeExtension('${sassId.extension}.css'));
    } catch (e, s) {
      if (e is! AssetNotFoundException) {
        throw new StateError('$e (${e.runtimeType})\n$s');
      }

      // We failed to load the converted result, so run sassc ourselves.
      var sassAsset = transform.primaryInput;
      var stopwatch = new Stopwatch()..start();
      var result = await runSassC(
        sassAsset, isDebug: settings.isDebug,
        settings: await settings.sasscSettings);
      transform.logger.info('Running sassc on $sassId took ${stopwatch.elapsed.inMilliseconds} msec.');

      result.messages.forEach((m) => m.log(transform));

      if (result.success) {
        if (!settings.isDebug) transform.consumePrimary();
        transform.addOutput(result.css);
        transform.addOutput(result.map);
      }
    }
  }
}

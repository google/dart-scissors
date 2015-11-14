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
library scissors.src.sass.sass_and_css_pruning_transformer;

import 'dart:async';

import 'package:barback/barback.dart';

import '../utils/deps_consumer.dart';
import '../utils/settings_base.dart';
import 'sassc.dart' show SasscSettings, runSassC;
import 'package:scissors/src/utils/path_resolver.dart';

abstract class SassSettings {
  bool get isDebug;

  final compileSass = new Setting<bool>('compileSass', defaultValue: true);

  // final fallbackToRubySass = new Setting<bool>('fallbackToRubySass',
  //     comment: "Whether to fallback to JRuby+Ruby Sass when SassC fails.\n"
  //         "This can help with some keyframe syntax in Compass stylesheets.",
  //     defaultValue: false);

  // final jrubyPath = makePathSetting('jrubyPath', pathResolver.defaultJRubyPath);

  // final rubySassPath =
  //     makePathSetting('rubySassPath', pathResolver.defaultRubySassPath);

  final compassStylesheetsPath = makePathSetting(
      'compassStylesheetsPath', pathResolver.defaultCompassStylesheetsPath);

  final sasscPath =
      makePathSetting('sasscPath', pathResolver.defaultSassCPath);

  final sasscArgs = new Setting<List<String>>('sasscArgs', defaultValue: []);

  Future<SasscSettings> _sasscSettings;
  Future<SasscSettings> get sasscSettings {
    if (_sasscSettings == null) {

      _sasscSettings = (() async {
        var path =
            await pathResolver.resolvePath(resolveEnvVars(sasscPath.value));
        var args = [];
        for (var dir in await pathResolver.getSassIncludeDirectories()) {
          args..add("--load-path")..add(dir.path);
        }
        args.addAll(sasscArgs.value.map(resolveEnvVars) ?? []);

        return new SasscSettings(path, args);
      })();
    }
    return _sasscSettings;
  }
}

class _SassSettings extends SettingsBase with SassSettings {
  _SassSettings.fromSettings(settings)
      : super.fromSettings(settings);
}

class SassTransformer extends Transformer implements DeclaringTransformer {
  final SassSettings settings;

  SassTransformer(this.settings);
  SassTransformer.asPlugin(BarbackSettings settings)
      : this(new _SassSettings.fromSettings(settings));

  @override String get allowedExtensions =>
      settings.compileSass.value ? ".sass .scss" : ".no-such-extension";

  @override
  declareOutputs(DeclaringTransform transform) {
    if (!settings.isDebug) transform.consumePrimary();

    var id = transform.primaryId;
    transform.declareOutput(id.addExtension('.css'));
    transform.declareOutput(id.addExtension('.css.map'));
  }

  Future apply(Transform transform) async {
    var scss = transform.primaryInput;

    // Mark transitive SASS @imports as barback dependencies.
    var depsConsumption = consumeTransitiveSassDeps(transform, scss);

    var result = await runSassC(scss,
        isDebug: settings.isDebug, settings: await settings.sasscSettings);
    result.logMessages(transform);

    await depsConsumption;

    if (!result.success) return null;

    if (!settings.isDebug) transform.consumePrimary();
    transform.addOutput(result.css);
    if (result.map != null) transform.addOutput(result.map);
  }
}

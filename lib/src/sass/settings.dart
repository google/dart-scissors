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
part of scissors.src.sass.sass_and_css_pruning_transformer;

abstract class SassSettings {
  bool get isDebug;

  final compileSass = new Setting<bool>('compileSass', defaultValue: true);

  final onlyCompileOutOfDateSass = new Setting<bool>('onlyCompileOutOfDateSass', defaultValue: true);

  // final fallbackToRubySass = new Setting<bool>('fallbackToRubySass',
  //     comment: "Whether to fallback to JRuby+Ruby Sass when SassC fails.\n"
  //         "This can help with some keyframe syntax in Compass stylesheets.",
  //     defaultValue: false);

  // final jrubyPath = makePathSetting('jrubyPath', pathResolver.defaultJRubyPath);

  // final rubySassPath =
  //     makePathSetting('rubySassPath', pathResolver.defaultRubySassPath);

  final compassStylesheetsPath = makePathSetting(
      'compassStylesheetsPath', pathResolver.defaultCompassStylesheetsPath);

  final sasscPath = makePathSetting('sasscPath', pathResolver.defaultSassCPath);

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
  _SassSettings(settings) : super(settings);
}

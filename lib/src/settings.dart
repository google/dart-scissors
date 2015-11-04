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
library scissors.src.settings;

import 'dart:async';
import 'dart:io';

import 'package:barback/barback.dart';
import 'package:quiver/check.dart';

import 'enum_parser.dart';
import 'image_inliner.dart';
import 'path_resolver.dart';
import 'sassc.dart';

part 'setting.dart';

class ScissorsSettings {
  final bool isDebug;

  final verbose = new _Setting<bool>('verbose', defaultValue: false);

  final compileSass = new _Setting<bool>('compileSass', defaultValue: true);

  final pruneCss = new _Setting<bool>('pruneCss', defaultValue: true);

  final optimizeSvg = new _Setting<bool>('optimizeSvg',
      debugDefault: false, releaseDefault: true);

  final optimizePng = new _Setting<bool>('optimizePng',
      debugDefault: false, releaseDefault: true);

  final mirrorCss = new _Setting<bool>('mirrorCss',
      comment:
          "Whether to perform LTR -> RTL mirroring of .css files with cssjanus.",
      defaultValue: false);

  final fallbackToRubySass = new _Setting<bool>('fallbackToRubySass',
      comment: "Whether to fallback to JRuby+Ruby Sass when SassC fails.\n"
          "This can help with some keyframe syntax in Compass stylesheets.",
      defaultValue: false);

  final cssJanusPath = new _Setting<String>('cssJanusPath',
      defaultValue: pathResolver.defaultCssJanusPath);

  final pngCrushPath = new _Setting<String>('pngCrushPath',
      defaultValue: pathResolver.defaultPngCrushPath);

  final jrubyPath = new _Setting<String>('jrubyPath',
      defaultValue: pathResolver.defaultJRubyPath);

  final rubySassPath = new _Setting<String>('rubySassPath',
      defaultValue: pathResolver.defaultRubySassPath);

  final compassStylesheetsPath = new _Setting<String>('compassStylesheetsPath',
      defaultValue: pathResolver.defaultCompassStylesheetsPath);

  final imageInlining = new _Setting<ImageInliningMode>('imageInlining',
      debugDefault: ImageInliningMode.linkInlinedImages,
      releaseDefault: ImageInliningMode.inlineInlinedImages,
      parser:
          new EnumParser<ImageInliningMode>(ImageInliningMode.values).parse);

  final _sasscPath = new _Setting<String>('sasscPath',
      defaultValue: pathResolver.defaultSassCPath);

  final _sasscArgs = new _Setting<List<String>>('sasscArgs', defaultValue: []);

  Future<SasscSettings> _sasscSettings;
  Future<SasscSettings> get sasscSettings => _sasscSettings;

  static const _debugConfigKey = 'debug';
  static const _releaseConfigKey = 'release';

  ScissorsSettings.fromSettings(BarbackSettings settings)
      : isDebug = settings.mode == BarbackMode.DEBUG {
    var config = settings.configuration;
    config.addAll(config[isDebug ? _debugConfigKey : _releaseConfigKey] ?? {});

    var settingList = <_Setting>[
      verbose,
      compileSass,
      pruneCss,
      mirrorCss,
      optimizeSvg,
      optimizePng,
      imageInlining,
      fallbackToRubySass,
      cssJanusPath,
      jrubyPath,
      rubySassPath,
      compassStylesheetsPath,
      _sasscPath,
      _sasscArgs,
    ];
    var validKeys = []
      ..addAll(settingList.map((s) => s.key))
      ..add(_debugConfigKey)
      ..add(_releaseConfigKey);

    var invalidKeys = config.keys.where((k) => !validKeys.contains(k));
    checkState(invalidKeys.isEmpty,
        message: () =>
            "Invalid keys in configuration: $invalidKeys (valid keys: ${validKeys})");

    settingList.forEach((s) => s.read(config, isDebug));

    _sasscSettings = (() async {
      var path =
          await pathResolver.resolvePath(_resolveEnvVars(_sasscPath.value));
      var args = [];
      for (var dir in await pathResolver.getSassIncludeDirectories()) {
        args..add("--load-path")..add(dir.path);
      }
      args.addAll(_sasscArgs.value.map(_resolveEnvVars) ?? []);

      return new SasscSettings(path, args);
    })();
  }
}

String _resolveEnvVars(String s) => s.replaceAllMapped(
    new RegExp(r'\$\{([^}]+)\}'),
    (Match m) => (Platform.environment[m.group(1)] ?? ''));

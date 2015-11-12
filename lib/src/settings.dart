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

_Setting<String> makePathSetting(String name, String defaultValue) =>
    new _Setting<String>(name,
        defaultValue: defaultValue, parser: _resolveEnvVars);

_Setting<bool> makeOptimSetting(String name, [bool enabled = true]) =>
    new _Setting<bool>(name, debugDefault: false, releaseDefault: enabled);

class ScissorsSettings {
  final bool isDebug;

  final verbose = new _Setting<bool>('verbose', defaultValue: false);

  final expectedPartCounts =
      new _Setting<Map>('expectedPartCounts', defaultValue: {});

  final compileSass = new _Setting<bool>('compileSass', defaultValue: true);

  final pruneCss = new _Setting<bool>('pruneCss', defaultValue: true);

  final ltrImport = new _Setting<String>('ltrImport');
  final rtlImport = new _Setting<String>('rtlImport');

  final reoptimizePermutations =
      makeOptimSetting('reoptimizePermutations', false);
  final optimizeSvg = makeOptimSetting('optimizeSvg');
  final optimizePng = makeOptimSetting('optimizePng');

  final mirrorCss = new _Setting<bool>('mirrorCss',
      comment:
          "Whether to perform LTR -> RTL mirroring of .css files with cssjanus.",
      defaultValue: false);

  final fallbackToRubySass = new _Setting<bool>('fallbackToRubySass',
      comment: "Whether to fallback to JRuby+Ruby Sass when SassC fails.\n"
          "This can help with some keyframe syntax in Compass stylesheets.",
      defaultValue: false);

  final imageInlining = new _Setting<ImageInliningMode>('imageInlining',
      debugDefault: ImageInliningMode.linkInlinedImages,
      releaseDefault: ImageInliningMode.inlineInlinedImages,
      parser:
          new EnumParser<ImageInliningMode>(ImageInliningMode.values).parse);

  final packageRewrites = new _Setting<String>('packageRewrites',
      defaultValue: "^package:,packages/");

  final cssJanusPath =
      makePathSetting('cssJanusPath', pathResolver.defaultCssJanusPath);

  final javaPath = makePathSetting('javaPath', pathResolver.defaultJavaPath);

  final closureCompilerJarPath = makePathSetting(
      'closureCompilerJar', pathResolver.defaultClosureCompilerJarPath);

  final pngCrushPath =
      makePathSetting('pngCrushPath', pathResolver.defaultPngCrushPath);

  final jrubyPath = makePathSetting('jrubyPath', pathResolver.defaultJRubyPath);

  final rubySassPath =
      makePathSetting('rubySassPath', pathResolver.defaultRubySassPath);

  final compassStylesheetsPath = makePathSetting(
      'compassStylesheetsPath', pathResolver.defaultCompassStylesheetsPath);

  final _sasscPath =
      makePathSetting('sasscPath', pathResolver.defaultSassCPath);

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
      expectedPartCounts,
      compileSass,
      pruneCss,
      mirrorCss,
      optimizeSvg,
      optimizePng,
      reoptimizePermutations,
      ltrImport,
      rtlImport,
      imageInlining,
      fallbackToRubySass,
      javaPath,
      pngCrushPath,
      cssJanusPath,
      jrubyPath,
      rubySassPath,
      compassStylesheetsPath,
      closureCompilerJarPath,
      packageRewrites,
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

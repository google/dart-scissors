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
library scissors.settings;

import 'dart:async';
import 'dart:io';

import 'package:barback/barback.dart';
import 'package:quiver/check.dart';

import 'path_resolver.dart';
import 'sassc.dart';

class ScissorsSettings {
  bool _isDebug;
  bool _isVerbose;
  bool _pruneCss;
  bool _inlineImages;
  Future<SasscSettings> _sasscSettings;

  static const _SASSC_PATH_PARAM = 'sasscPath';
  static const _SASSC_ARGS_PARAM = 'sasscArgs';
  static const _VERBOSE_PARAM = 'verbose';
  static const _PRUNE_CSS_PARAM = 'pruneCss';
  static const _INLINE_IMAGES_PARAM = 'inlineImages';
  static const _VALID_PARAMS = const [
    _SASSC_PATH_PARAM,
    _SASSC_ARGS_PARAM,
    _VERBOSE_PARAM,
    _PRUNE_CSS_PARAM,
    _INLINE_IMAGES_PARAM
  ];

  ScissorsSettings.fromSettings(BarbackSettings settings) {
    _isDebug = settings.mode == BarbackMode.DEBUG;
    var config = settings.configuration;

    var invalidKeys = config.keys.where((k) => !_VALID_PARAMS.contains(k));
    checkState(invalidKeys.isEmpty,
        message: () =>
            "Invalid keys in configuration: $invalidKeys (valid keys: ${_VALID_PARAMS})");

    _sasscSettings = (() async {
      var path = await pathResolver.resolvePath(_resolveEnvVars(
          config[_SASSC_PATH_PARAM] ?? pathResolver.defaultSassCPath));
      var args = [];
      for (var dir in await pathResolver.sassIncludeDirectories) {
        args..add("--load-path")..add(dir.path);
      }
      args.addAll(config[_SASSC_ARGS_PARAM]?.map(_resolveEnvVars) ?? []);

      return new SasscSettings(path, args);
    })();

    _isVerbose = config[_VERBOSE_PARAM] ?? false;
    _pruneCss = config[_PRUNE_CSS_PARAM] ?? true;
    _inlineImages = config[_INLINE_IMAGES_PARAM] ?? true;
  }

  bool get isDebug => _isDebug;
  bool get isVerbose => _isVerbose;
  bool get pruneCss => _pruneCss;
  bool get inlineImages => _inlineImages;
  Future<SasscSettings> get sasscSettings => _sasscSettings;
}

String _resolveEnvVars(String s) => s.replaceAllMapped(
    new RegExp(r'\$\{([^}]+)\}'),
    (Match m) => (Platform.environment[m.group(1)] ?? ''));

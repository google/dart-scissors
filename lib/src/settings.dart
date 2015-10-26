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

class ScissorsSettings {
  bool _isDebug;
  Future<String> _sasscPath;
  Future<List<String>> _sasscArgs;

  static const _DEFAULT_SASSC_PATH = 'sassc';
  static const _SASSC_PATH_PARAM = 'sasscPath';
  static const _SASSC_ARGS_PARAM = 'sasscArgs';
  static const _VALID_PARAMS = const [_SASSC_PATH_PARAM, _SASSC_ARGS_PARAM];

  ScissorsSettings.fromSettings(BarbackSettings settings) {
    _isDebug = settings.mode == BarbackMode.DEBUG;
    var config = settings.configuration;

    var invalidKeys = config.keys.where((k) => !_VALID_PARAMS.contains(k));
    checkState(invalidKeys.isEmpty,
        message: () => "Invalid keys in configuration: $invalidKeys (valid keys: ${_VALID_PARAMS})");

    _sasscPath = resolvePath(
        _resolveEnvVars(config[_SASSC_PATH_PARAM] ?? _DEFAULT_SASSC_PATH));
    _sasscArgs = (() async {
      var args = [];
      for (var dir in await getRootDirectories()) {
        args.addAll(["--load-path", dir]);
      }
      args.addAll(config[_SASSC_ARGS_PARAM]?.map(_resolveEnvVars) ?? []);
      return args;
    })();
  }

  bool get isDebug => _isDebug;
  Future<String> get sasscPath => _sasscPath;
  Future<List<String>> get sasscArgs => _sasscArgs;
}


String _resolveEnvVars(String s) =>
    s.replaceAllMapped(
        new RegExp(r'\$\{([^}]+)\}'),
        (Match m) => (Platform.environment[m.group(1)] ?? ''));

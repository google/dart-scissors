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
library scissors.src.utils.settings_base;

import 'dart:async';
import 'dart:io';
import 'dart:mirrors';

import 'package:barback/barback.dart';
import 'package:quiver/check.dart';

import 'path_resolver.dart';

part 'setting.dart';

Future<String> _resolve(String path, {bool isExecutable: false}) async {
  path = resolveEnvVars(path);
  if (isExecutable) {
    return await pathResolver.resolveExecutable(path);
  } else {
    return await pathResolver.resolvePath(path);
  }
}

Setting<Future<String>> makePathSetting(String name, String defaultValue,
        {bool isExecutable: false}) =>
    new Setting<Future<String>>(name,
        defaultValue: new Future.value(
            _resolve(defaultValue, isExecutable: isExecutable)),
        parser: _resolve);

Setting<bool> makeBoolSetting(String name, [bool enabled = true]) =>
    new Setting<bool>(name, defaultValue: enabled);

Setting<bool> makeOptimSetting(String name, [bool enabled = true]) =>
    new Setting<bool>(name, debugDefault: false, releaseDefault: enabled);

abstract class SettingsBase {
  final BarbackSettings _settings;
  bool get isDebug => _settings.mode == BarbackMode.DEBUG;

  final _verbose = new Setting<bool>('verbose', defaultValue: false);
  Setting<bool> get verbose => _verbose;

  static const _debugConfigKey = 'debug';
  static const _releaseConfigKey = 'release';

  SettingsBase(this._settings) {
    var config = _settings.configuration.cast<String, dynamic>();
    config.addAll(config[isDebug ? _debugConfigKey : _releaseConfigKey]
            as Map<String, dynamic> ??
        const <String, dynamic>{});

    var settingList = getAllSettings();
    var validKeys = []
      ..addAll(settingList.map((s) => s.key))
      ..add(_debugConfigKey)
      ..add(_releaseConfigKey);

    var invalidKeys = config.keys.where((k) => !validKeys.contains(k));
    checkState(invalidKeys.isEmpty,
        message: () =>
            "Invalid keys in configuration: $invalidKeys (valid keys: $validKeys)");

    settingList.forEach((s) => s.read(config, isDebug));
  }

  List<Setting> getAllSettings() {
    var settingList = <Setting>[];
    InstanceMirror m = reflect(this);
    var settingType = reflectType(Setting);
    m.type.instanceMembers.forEach((Symbol name, MethodMirror mm) {
      if (!mm.isGetter || mm.isPrivate) return;
      if (!mm.returnType.isAssignableTo(settingType)) return;

      var value = m.getField(name).reflectee;
      if (value is Setting) settingList.add(value);
    });
    return settingList;
  }
}

String resolveEnvVars(String s) => s?.replaceAllMapped(
    new RegExp(r'\$\{([^}]+)\}'),
    (Match m) => (Platform.environment[m.group(1)] ?? ''));

// final bidiCss = new Setting<bool>('bidiCss',
//     comment:
//         "Whether to perform LTR -> RTL mirroring of .css files with cssjanus.",
//     defaultValue: false);

// final cssJanusPath =
//     makePathSetting('cssJanusPath', pathResolver.defaultCssJanusPath);

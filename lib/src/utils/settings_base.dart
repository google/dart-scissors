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
library scissors.src.settings_base;

import 'dart:io';
import 'dart:mirrors';

import 'package:barback/barback.dart';
import 'package:quiver/check.dart';

import 'setting.dart';
export 'setting.dart';

Setting<String> makePathSetting(String name, String defaultValue) =>
    new Setting<String>(name,
        defaultValue: defaultValue, parser: resolveEnvVars);

Setting<bool> makeBoolSetting(String name, [bool enabled = true]) =>
    new Setting<bool>(name, defaultValue: enabled);

Setting<bool> makeOptimSetting(String name, [bool enabled = true]) =>
    new Setting<bool>(name, debugDefault: false, releaseDefault: enabled);

abstract class SettingsBase {
  final bool isDebug;

  final verbose = new Setting<bool>('verbose', defaultValue: false);

  static const _debugConfigKey = 'debug';
  static const _releaseConfigKey = 'release';

  SettingsBase.fromSettings(BarbackSettings settings)
      : isDebug = settings.mode == BarbackMode.DEBUG {
    var config = settings.configuration;
    config.addAll(config[isDebug ? _debugConfigKey : _releaseConfigKey] ?? {});

    var settingList = getAllSettings();
    var validKeys = []
      ..addAll(settingList.map((s) => s.key))
      ..add(_debugConfigKey)
      ..add(_releaseConfigKey);

    var invalidKeys = config.keys.where((k) => !validKeys.contains(k));
    checkState(invalidKeys.isEmpty,
        message: () =>
            "Invalid keys in configuration: $invalidKeys (valid keys: ${validKeys})");

    settingList.forEach((s) => s.read(config, isDebug));
  }

  List<Setting> getAllSettings() {
    var settingList = <Setting>[];
    InstanceMirror m = reflect(this);
    m.type.instanceMembers.forEach((Symbol name, MethodMirror mm) {
      if (mm.isGetter) {
        var value = m.getField(name).reflectee;
        if (value is Setting) settingList.add(value);
      }
    });
    return settingList;
  }
}

String resolveEnvVars(String s) => s.replaceAllMapped(
    new RegExp(r'\$\{([^}]+)\}'),
    (Match m) => (Platform.environment[m.group(1)] ?? ''));

// final mirrorCss = new Setting<bool>('mirrorCss',
//     comment:
//         "Whether to perform LTR -> RTL mirroring of .css files with cssjanus.",
//     defaultValue: false);

// final cssJanusPath =
//     makePathSetting('cssJanusPath', pathResolver.defaultCssJanusPath);

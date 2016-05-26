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
part of scissors.src.css_mirroring.transformer;

const _bidiCssSetting = 'bidiCss';

abstract class CssMirroringSettings {
  Setting<bool> get verbose;

  final _bidiCss = new Setting<bool>(_bidiCssSetting, defaultValue: false);
  Setting<bool> get bidiCss => _bidiCss;

  final originalCssDirection = new Setting<Direction>('originalCssDirection',
      defaultValue: Direction.ltr,
      parser: new EnumParser<Direction>(Direction.values).parse);
  final cssJanusPath =
      makePathSetting('cssJanusPath', pathResolver.defaultCssJanusPath);
}

class _CssMirroringSettings extends SettingsBase with CssMirroringSettings {
  _CssMirroringSettings(settings) : super(settings);

  @override
  final bidiCss = new Setting<bool>(_bidiCssSetting, defaultValue: true);
}

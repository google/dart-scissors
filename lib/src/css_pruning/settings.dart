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
part of scissors.src.css_pruning.transformer;

abstract class CssPruningSettings {
  Setting<bool> get verbose;

  final pruningScheme = new Setting<PruningScheme>('pruningScheme',
      debugDefault: PruningScheme.skip,
      releaseDefault: PruningScheme.overwrite,
      parser: new EnumParser<PruningScheme>(PruningScheme.values).parse);

  // final bidiCss = new Setting<bool>('bidiCss',
  //     comment:
  //         "Whether to perform LTR -> RTL mirroring of .css files with cssjanus.",
  //     defaultValue: false);
}

class _CssPruningSettings extends SettingsBase with CssPruningSettings {
  _CssPruningSettings(settings) : super(settings);
}

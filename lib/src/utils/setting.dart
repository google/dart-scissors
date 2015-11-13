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
library scissors.src.utils.setting;

import 'package:quiver/check.dart';

class Setting<T> {
  final String key;
  final String comment;
  final T debugDefault;
  final T releaseDefault;
  final Function parser;
  bool _read = false;
  T _value;
  T get value {
    checkState(_read, message: () => "Setting $key wasn't read yet.");
    return _value;
  }

  Setting(this.key,
      {this.comment,
      T defaultValue,
      T debugDefault,
      T releaseDefault,
      T this.parser(String s)})
      : this.debugDefault = debugDefault ?? defaultValue,
        this.releaseDefault = releaseDefault ?? defaultValue;

  read(Map config, bool isDebug) {
    checkState(!_read);
    _read = true;
    var value = config[key];
    if (value == null) {
      _value = isDebug ? debugDefault : releaseDefault;
    } else {
      _value = parser != null ? parser(value) : value;
    }
  }
}

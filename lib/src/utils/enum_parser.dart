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
library scissors.src.utils.enum_parser;

import 'package:quiver/check.dart';

String enumName(dynamic value) {
  var split = value.toString().split('.');
  checkArgument(split.length == 2,
      message: () => "Unrecognized enum name: $value");
  return split[1];
}

class EnumParser<E> {
  Map<String, E> _byName;
  EnumParser._(this._byName);
  factory EnumParser(List<E> values) =>
      new EnumParser._(new Map.fromIterable(values, key: enumName));

  E parse(String name) {
    var value = _byName[name];
    if (value == null) {
      throw new ArgumentError('Invalid value $name '
          '(expected one of ${_byName.keys.join(', ')}');
    }
    return value;
  }
}

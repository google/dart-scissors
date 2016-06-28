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
library scissors.src.css_pruning.ng_class_parser;

import 'package:quiver/check.dart';

final RegExp _identifierRx = new RegExp(r'^[\w\d_]+$');

/// Result of parsing an ng-class attribute.
class NgClassParsingResults {
  final bool hasVariableClasses;
  final List<String> classes;
  NgClassParsingResults(this.hasVariableClasses, this.classes) {
    checkNotNull(hasVariableClasses);
    checkNotNull(classes);
  }

  /// For test purposes.
  @override
  operator ==(other) =>
      other is NgClassParsingResults &&
      hasVariableClasses == other.hasVariableClasses &&
      "$classes" == "${other.classes}";
  @override
  get hashCode => hasVariableClasses.hashCode ^ "$classes".hashCode;
}

/// Try to parse naive ng-class maps, or return `null` if the format is unknown.
///
/// Does a best-effort parsing for simple key-values, with keys being string
/// literals or identifiers.
NgClassParsingResults parseNgClassAttribute(String attributeValue) {
  attributeValue = attributeValue.trim();
  if (!attributeValue.startsWith("{") || !attributeValue.endsWith("}")) {
    // Not a map literal.
    return null;
  }
  // Body of the map (inside the curly braces).
  final mapBody = attributeValue.substring(1, attributeValue.length - 1).trim();

  bool hasVariableClasses = false;
  final List<String> classes = [];

  if (mapBody.isNotEmpty) {
    for (final keyValue in mapBody.split(",").map(_trimmer)) {
      if (keyValue.isEmpty) continue;

      var kv = keyValue.split(":").map(_trimmer).toList();
      if (kv.length != 2) {
        return null;
      }
      var key = kv[0];
      if ((key.startsWith("'") && key.endsWith("'")) ||
          (key.startsWith('"') && key.endsWith('"'))) {
        // Key is a string literal.
        if (key.contains(r'$')) {
          // Literal is a string interpolation: bailing out of parsing.
          return null;
        }
        final className = key.substring(1, key.length - 1);
        classes.add(className);
      } else if (_identifierRx.hasMatch(key)) {
        // Key is an identifier.
        hasVariableClasses = true;
      } else {
        // Weird key: bailing out of parsing.
        return null;
      }
    }
  }

  return new NgClassParsingResults(hasVariableClasses, classes);
}

String _trimmer(String s) => s.trim();

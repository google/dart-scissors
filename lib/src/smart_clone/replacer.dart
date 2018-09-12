// Copyright 2017 Google Inc. All Rights Reserved.
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

import 'cases.dart';
import 'inflections.dart';

final caseInsensitiveTransforms = <StringTransform>[
  (s) => s.replaceAll('-', '_'),
  (s) => s.replaceAll('_', '-'),
  packageToPath,
  pathToPackage,
  (s) => decamelize(s, '_'),
  (s) => decamelize(s, '-'),
];
final caseSensitiveTransforms = <StringTransform>[
  underscoresToCamel,
  (s) => capitalize(underscoresToCamel(s)),
  hyphensToCamel,
  (s) => capitalize(hyphensToCamel(s)),
];

class Replacer extends Function {
  final _replacedPatterns = new Set<String>();
  final _replacements = <RegExp, String>{};
  final _patterns = <RegExp>[];
  final bool strict;
  final bool allowInflections;
  Replacer({this.strict : true, this.allowInflections : true});

  static const _patternSuffix = r'(?:$|\b|(?=\d|[-_A-Z]))';
  static const _patternPrefix = r'(\b|\d|[-_A-Z])';

  void addReplacements(String original, String replacement) {
    final variations = allowInflections ? English.inflections : [identity];
    for (final variation in variations) {
      for (final transform in caseSensitiveTransforms) {
        _addReplacement(original, replacement, (s) => transform(variation(s)));
        _addReplacement(
            original, replacement, (s) => capitalize(transform(variation(s))));
        _addReplacement(original, replacement,
            (s) => decapitalize(transform(variation(s))));
      }
      for (final transform in caseInsensitiveTransforms) {
        _addReplacement(original, replacement, (s) => transform(variation(s)));
        _addReplacement(original, replacement,
            (s) => transform(variation(s)).toUpperCase());
        _addReplacement(original, replacement,
            (s) => transform(variation(s)).toLowerCase());
      }
    }
  }

  void _addReplacement(
      String original, String replacement, StringTransform transform) {
    final transformed = transform(original);

    // if (transformed == original) continue;
    String pattern = (strict ? _patternPrefix : '') + transformed + (strict ? _patternSuffix : '');
    if (_replacedPatterns.add(pattern)) {
      final rx = new RegExp(pattern);
      _patterns.add(rx);
      _replacements[rx] = transform(replacement);
    }
  }

  toString() {
    var s = '{\n';
    _replacements.forEach((k, v) {
      s += '  ${k.pattern} -> $v\n';
    });
    s += '}';
    return s;
  }

  String call(String s) {
    for (final pattern in _patterns) {
      s = s.replaceAllMapped(pattern, (m) {
        final replacement = _replacements[pattern];
        if (strict) {
          return m.group(1) + replacement;
        }
        return replacement;
      });
    }
    return s;
  }
}

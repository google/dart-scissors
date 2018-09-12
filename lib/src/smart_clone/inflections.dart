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

Map<String, String> invertMap(Map<String, String> map) =>
    new Map.fromIterable(map.keys, key: (k) => map[k]);

_stripFinalE(String s) => s.endsWith('e') ? s.substring(0, s.length - 1) : s;

// TODO(ochafik): Use package:inflection.
class English {
  static final inflections = <StringTransform>[
    identity,
    doubleLetterPluralize,
    pluralize,
    singularize,
    _suffixAdder('er'),
    _suffixAdder('ed'),
    _suffixAdder('ing'),
  ];

  static bool _turnsYsToIes(String suffix) =>
      suffix.startsWith('e')
      || suffix.startsWith('i');

  static StringTransform _suffixAdder(String suffix) {
    return (String s) {
      var prefix = doubleFinalLetter(_stripFinalE(s));
      if (prefix.toLowerCase().endsWith('y')
          && (suffix.toLowerCase().startsWith('e')
              || s.toLowerCase() == 'sky' && suffix == 'ing')) {
        prefix = prefix.substring(0, prefix.length - 1) + 'i';
      }
      return prefix + suffix;
    };
  }

  static final consonants = new Set.from([
    'b', 'd', 'f', 'g', 'l', 'm', 'n', 'p', 't', 'v', 'z',
    'c', 'j', 'k', 'q', 's', 'w', 'x', 'r'
  ]);
  static final doubledConsonants = new Set.from([
    'b', 'd', 'f', 'g', 'l', 'm', 'n', 'p', 'r', 't', 'v', 'z',
    // 'c', 'j', 'k', 'q', 's', 'w', 'x', 'r'
  ]);
  static bool shouldDoubleFinalLetter(String s) {
    if (s.length < 2) return false;
    final c = s[s.length - 1];
    final previous = s[s.length - 2];
    return doubledConsonants.contains(c)
        && !consonants.contains(previous);
  }

  static String doubleFinalLetter(String s) {
    if (shouldDoubleFinalLetter(s)) return s + s[s.length - 1];
    return s;
  }

  static final _knownPlurals = {
    'child': 'children',
    'criterion': 'criteria',
    'foot': 'feet',
    'leaf': 'leaves',
    'life': 'lives',
    'person': 'people',
    'formula': 'formulae',
  };
  static final _knownSingulars = invertMap(_knownPlurals);
  static final _knownPluralSuffices = {
    'ay': 'ays',
    'ey': 'eys',
    'y': 'ies',
    'ix': 'ices',
    'ex': 'ices',
    'is': 'es',
    'ro': 'roes',
    'um': 'a',
    'us': 'i',
    's': 'ses',
    '': 's'
  };
  static final _knownSingularSuffices = invertMap(_knownPluralSuffices);

  static String _replaceSuffix(String s, int length, String to) =>
      s.substring(0, s.length - length) + to;

  static String pluralize(String s) {
    final knownPlural = _knownPlurals[s.toLowerCase()];
    if (knownPlural != null) return knownPlural;

    if (s.length > 1) {
      for (final suffix in _knownPluralSuffices.keys) {
        if (s.endsWith(suffix)) {
          return _replaceSuffix(s, suffix.length, _knownPluralSuffices[suffix]);
        }
      }
    }
    return s;
  }

  static String singularize(String s) {
    final knownSingular = _knownSingulars[s];
    if (knownSingular != null) return knownSingular;

    if (s.length > 1) {
      for (final suffix in _knownSingularSuffices.keys) {
        if (s.endsWith(suffix)) {
          return _replaceSuffix(
              s, suffix.length, _knownSingularSuffices[suffix]);
        }
      }
    }
    return s;
  }

  static String doubleLetterPluralize(String s) {
    if (shouldDoubleFinalLetter(s)) return doubleFinalLetter(s) + 'es';
    return pluralize(s);
  }
}

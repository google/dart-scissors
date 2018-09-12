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

import 'package:test/test.dart';
import 'package:scissors/src/smart_clone/cases.dart';

main() {
  group('cases', () {
    test('capitalize', () {
      expect(capitalize('abc'), 'Abc');
      expect(capitalize('aBC'), 'ABC');
      expect(capitalize('ABC'), 'ABC');
    });
    test('decapitalize', () {
      expect(decapitalize('abc'), 'abc');
      expect(decapitalize('aBC'), 'aBC');
      expect(decapitalize('ABC'), 'aBC');
    });
    test('underscoresToCamel', () {
      expect(underscoresToCamel('ab'), 'ab');
      expect(underscoresToCamel('AB'), 'AB');
      expect(underscoresToCamel('ab_cd_ef'), 'abCdEf');
    });
    test('hyphensToCamel', () {
      expect(hyphensToCamel('ab'), 'ab');
      expect(hyphensToCamel('AB'), 'AB');
      expect(hyphensToCamel('ab-cd-ef'), 'abCdEf');
    });
    test('decamelize', () {
      expect(decamelize('ab'), 'ab');
      expect(decamelize('AB'), 'a_b');
      expect(decamelize('abCdEf'), 'ab_cd_ef');
    });
    test('packageToPath', () {
      expect(packageToPath('ab'), 'ab');
      expect(packageToPath('ab.cd'), 'ab/cd');
    });
    test('pathToPackage', () {
      expect(pathToPackage('ab'), 'ab');
      expect(pathToPackage('ab/cd'), 'ab.cd');
    });
  });
}

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
import 'package:scissors/src/smart_clone/replacer.dart';

main() {
  group('Replacer', () {
    Replacer replacer;

    setUp(() {
      replacer = new Replacer();
    });

    void expectAllReplacements() {
      expect(replacer('fooBar'), 'bamBaz');
      expect(replacer('FooBar'), 'BamBaz');
      expect(replacer('foo-bar'), 'bam-baz');
      expect(replacer('FOO-BAR'), 'BAM-BAZ');
      expect(replacer('foo_bar'), 'bam_baz');
      expect(replacer('FOO_BAR'), 'BAM_BAZ');
    }

    group('with strict boundaries', () {
      test('enabled', () {
        replacer
          ..addReplacements('fooBar', 'bamBaz')
          ..addReplacements('GT', 'AS');
        expect(replacer('afooBar'), 'afooBar');
        expect(replacer('fooBare'), 'fooBare');
        expect(replacer('.length'), '.length');
      });

      test('disabled', () {
        replacer = new Replacer(strict: false)
          ..addReplacements('fooBar', 'bamBaz')
          ..addReplacements('GT', 'AS');
        expect(replacer('afooBar'), 'abamBaz');
        expect(replacer('fooBare'), 'bamBaze');
        expect(replacer('.length'), '.lenash');
      });
    });

    group('with inflections', () {
      test('enabled', () {
        replacer.addReplacements('fooBar', 'bamBaz');
        expect(replacer('fooBarrer'), 'bamBazzer');
      });

      test('disabled', () {
        replacer = new Replacer(allowInflections: false)
            ..addReplacements('fooBar', 'bamBaz');
        expect(replacer('fooBarrer'), 'fooBarrer');
      });
    });

    test('with camel case replacements', () {
      replacer.addReplacements('fooBar', 'bamBaz');
      expectAllReplacements();

      expect(replacer('afooBar'), 'afooBar');
      expect(replacer('fooBare'), 'fooBare');
    });

    test('with capitalized camel case replacements', () {
      replacer.addReplacements('FooBar', 'BamBaz');
      expectAllReplacements();
    });

    test('with hyphenated replacements', () {
      replacer.addReplacements('foo-bar', 'bam-baz');
      expectAllReplacements();
    });

    test('with underscores replacements', () {
      replacer.addReplacements('foo_bar', 'bam_baz');
      expectAllReplacements();
    });
  });
}

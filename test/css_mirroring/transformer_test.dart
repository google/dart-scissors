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
library scissors.test.css_mirroring.transformer_test;

import 'package:barback/barback.dart' show BarbackMode, BarbackSettings;
import 'package:scissors/src/css_mirroring/transformer.dart';
import 'package:test/test.dart';
import 'package:transformer_test/utils.dart' show testPhases, StringFormatter;

List<List> makePhases(Map config) => <List>[
      [
        new BidiCssTransformer.asPlugin(
            new BarbackSettings(config, BarbackMode.RELEASE))
      ]
    ];

void main() {
  var phases = makePhases({'bidiCss': true});

  testPhases(
    'splits the rule with language dependent declaration to common rule and language dependent rules',
    phases,
    {
      'a|foo2_unmatched_css_url.css': r'''
        absent-element {
          color: blue;
          float: right;
        }
      '''
    },
    {
      'a|foo2_unmatched_css_url.css': r'''
        absent-element {
          color: blue;
        }
        :host-context([dir="ltr"]) absent-element {
          float: right;
        }
        :host-context([dir="rtl"]) absent-element {
          float: left;
        }
      '''
    },
    formatter: StringFormatter.noNewlinesOrSurroundingWhitespace,
  );

  testPhases(
    'works on compact code',
    phases,
    {'a|foo_compact.css': r'.foo{color:blue;float:right;}.bar{}'},
    {
      'a|foo_compact.css': '.foo{color:blue;}.bar{}\n' +
          ':host-context([dir="ltr"]) .foo{float:right;}\n' +
          ':host-context([dir="rtl"]) .foo{float:left;}'
    },
    formatter: StringFormatter.noNewlinesOrSurroundingWhitespace,
  );

  testPhases(
    'honours and consumes cssjanus\'s /* @noflip */ comments',
    phases,
    {
      'a|foo_noflip.css': r'''
        /* @noflip */
        absent-element[dir="rtl"] {
          float: right;
        }
      '''
    },
    {
      'a|foo_noflip.css': r'''
        absent-element[dir="rtl"] {
          float: right;
        }
      '''
    },
    formatter: StringFormatter.noNewlinesOrSurroundingWhitespace,
  );

  testPhases(
    'keeps empty rules untouched',
    phases,
    {
      'a|foo2_unmatched_css_url.css': r'''
        .used-class {}
        .unused-class {}
      '''
    },
    {
      'a|foo2_unmatched_css_url.css': r'''
        .used-class {}
        .unused-class {}
      '''
    },
    formatter: StringFormatter.noNewlinesOrSurroundingWhitespace,
  );

  /// Changes rules contaning only direction dependent declarations to
  /// direction dependent rules without any rule for common values
  testPhases(
    'drops orientation-neutral rules when they are empty',
    phases,
    {
      'a|foo2_unmatched_css_url.css': r'''
        absent-element {
          float: left;
          margin-left: 100px;
        }
        .usedclass {
          padding: right;
          text-align: left;
        }
      '''
    },
    {
      'a|foo2_unmatched_css_url.css': r'''
        :host-context([dir="ltr"]) absent-element {
          float: left;
          margin-left: 100px;
        }
        :host-context([dir="ltr"]) .usedclass {
          padding: right;
          text-align: left;
        }
        :host-context([dir="rtl"]) absent-element {
          float: right;
          margin-right: 100px;
        }
        :host-context([dir="rtl"]) .usedclass {
          padding: left;
          text-align: right;
        }
      '''
    },
    formatter: StringFormatter.noNewlinesOrSurroundingWhitespace,
  );

  testPhases(
    'leaves orientation-neutral rules unchanged',
    phases,
    {
      'a|foo2_unmatched_css_url.css': r'''
        absent-element {
          color: blue;
        }
        .usedclass {
          background-size: 16px 16px;
        }
      '''
    },
    {
      'a|foo2_unmatched_css_url.css': r'''
        absent-element {
          color: blue;
        }
        .usedclass {
          background-size: 16px 16px;
        }
      '''
    },
    formatter: StringFormatter.noNewlinesOrSurroundingWhitespace,
  );

  testPhases(
    'splits the exotic rules with language dependent declaration to common rule and language dependent rules',
    phases,
    {
      'a|foo2_unmatched_css_url.css': r'''
        li + li {
          color: blue;
          float: right;
        }
        a ~ a {
          color: purple;
          margin-left: 3em;
        }
        li > a {
          color: orange;
          margin-left: 4em; width: 10px;
        }
      '''
    },
    {
      'a|foo2_unmatched_css_url.css': r'''
        li + li {
          color: blue;
          }
        a ~ a {
          color: purple;
          }
        li > a {
          color: orange;
          width: 10px;
        }
        :host-context([dir="ltr"]) li + li {
          float: right;
        }
        :host-context([dir="ltr"]) a ~ a {
          margin-left: 3em;
        }
        :host-context([dir="ltr"]) li > a {
          margin-left: 4em; }
        :host-context([dir="rtl"]) li + li {
          float: left;
        }
        :host-context([dir="rtl"]) a ~ a {
          margin-right: 3em;
        }
        :host-context([dir="rtl"]) li > a {
          margin-right: 4em; }
      '''
    },
    formatter: StringFormatter.noNewlinesOrSurroundingWhitespace,
  );

  var directionIndependentDirectives = {
    'charset': '''@charset "UTF-8";''',
    'import': '''@import url("fineprint.css") print;''',
    'font-face': '''@font-face {
      font-family: 'MyWebFont';
      src: url('myfont.woff2') format('woff2'),
      url('myfont.woff') format('woff');
    }''',
    'namespace': '''@namespace url(http://www.w3.org/1999/xhtml);'''
  };
  directionIndependentDirectives.forEach((directive, css) {
    /// Keeps direction independent directives like
    /// @charset, @import, @font-face, @namespace same.
    testPhases(
      'keeps $directive directive untouched',
      phases,
      {'a|foo2_unmatched_css_url.css': css},
      {'a|foo2_unmatched_css_url.css': css},
      formatter: StringFormatter.noNewlinesOrSurroundingWhitespace,
    );
  });

  /// Splits direction dependent directives @media to direction independent and
  /// dependent parts.
  testPhases(
    'splits direction dependent directives',
    phases,
    {
      'a|foo2_unmatched_css_url.css': r'''
        @media screen and (min-width: 401px) {
          body {
            margin-left: 13px;
            color: red;
          }
        }
      '''
    },
    {
      'a|foo2_unmatched_css_url.css': r'''
        @media screen and (min-width: 401px) {
          body {
            color: red;
          }
        }
        @media screen and (min-width: 401px) {
          :host-context([dir="ltr"]) body {
            margin-left: 13px;
          }
        }
        @media screen and (min-width: 401px) {
          :host-context([dir="rtl"]) body {
            margin-right: 13px;
          }
        }
      '''
    },
    formatter: StringFormatter.noNewlinesOrSurroundingWhitespace,
  );

  /// Splits direction dependent directives @media to direction independent and
  /// dependent parts and removes empty directives.
  testPhases(
    'splits direction dependent directives',
    phases,
    {
      'a|foo2_unmatched_css_url.css': r'''
        @media screen and (min-width: 401px) {
          body { margin-left: 13px }
        }
      '''
    },
    {
      'a|foo2_unmatched_css_url.css': r'''
        @media screen and (min-width: 401px) {
          :host-context([dir="ltr"]) body { margin-left: 13px }
        }
        @media screen and (min-width: 401px) {
          :host-context([dir="rtl"]) body { margin-right: 13px }
        }
      '''
    },
    formatter: StringFormatter.noNewlinesOrSurroundingWhitespace,
  );

  /// Keeps direction dependent directives @media same when none of the rules
  /// in it are modified
  testPhases(
    'splits direction dependent directives',
    phases,
    {
      'a|foo2_unmatched_css_url.css': r'''
        @media screen and (min-width: 401px) {
          body { color: red }
        }
      '''
    },
    {
      'a|foo2_unmatched_css_url.css': r'''
        @media screen and (min-width: 401px) {
          body { color: red }
        }
      '''
    },
    formatter: StringFormatter.noNewlinesOrSurroundingWhitespace,
  );

  /// Splits direction dependent directives @host to direction independent and
  /// dependent parts.
  testPhases(
    'splits direction dependent directives',
    phases,
    {
      'a|foo2_unmatched_css_url.css': r'''
        @host { :scope { padding: left; } }
      '''
    },
    {
      'a|foo2_unmatched_css_url.css': r'''
        @host { :host-context([dir="ltr"]) :scope { padding: left; } }
        @host { :host-context([dir="rtl"]) :scope { padding: right; } }
      '''
    },
    formatter: StringFormatter.noNewlinesOrSurroundingWhitespace,
  );

  testPhases(
    'adds direction to each selector in ruleset',
    phases,
    {
      'a|foo2_multiple_selectors_css_url.css': r'''
        .child1, .child2 {
          position: relative;
          margin-right: 10px;
        }
      '''
    },
    {
      'a|foo2_multiple_selectors_css_url.css': r'''
        .child1, .child2 {
          position: relative;
        }
        :host-context([dir="ltr"]) .child1, :host-context([dir="ltr"]) .child2 {
          margin-right: 10px;
        }
        :host-context([dir="rtl"]) .child1, :host-context([dir="rtl"]) .child2 {
          margin-left: 10px;
        }
      '''
    },
    formatter: StringFormatter.noNewlinesOrSurroundingWhitespace,
  );

  group('supports :host', () {
    testPhases(
      'in simple cases',
      phases,
      {
        'a|foo_host.css': r'''
          :host {
            position: absolute;
            padding-right: 10px;
          }
        '''
      },
      {
        'a|foo_host.css': r'''
          :host {
            position: absolute;
            }
          :host-context([dir="ltr"]) {
            padding-right: 10px;
          }
          :host-context([dir="rtl"]) {
            padding-left: 10px;
          }
        '''
      },
      formatter: StringFormatter.noNewlinesOrSurroundingWhitespace,
    );

    testPhases(
      'with a class',
      phases,
      {
        'a|foo_host.css': r'''
          :host.bar {
            position: relative;
            margin-right: 10px;
          }
        '''
      },
      {
        'a|foo_host.css': r'''
          :host.bar {
            position: relative;
          }
          :host-context([dir="ltr"]).bar {
            margin-right: 10px;
          }
          :host-context([dir="rtl"]).bar {
            margin-left: 10px;
          }
        '''
      },
      formatter: StringFormatter.noNewlinesOrSurroundingWhitespace,
    );

    testPhases(
      'with a selector',
      phases,
      {
        'a|foo_host.css': r'''
          :host(.class) {
            position: relative;
            left: 7px;
          }
          :host([attr]) {
            position: relative;
            left: 2em;
          }
        '''
      },
      {
        'a|foo_host.css': r'''
          :host(.class) {
            position: relative;
          }
          :host([attr]) {
            position: relative;
          }
          :host-context([dir="ltr"]):host(.class) {
            left: 7px;
          }
          :host-context([dir="ltr"]):host([attr]) {
            left: 2em;
          }
          :host-context([dir="rtl"]):host(.class) {
            right: 7px;
          }
          :host-context([dir="rtl"]):host([attr]) {
            right: 2em;
          }
        '''
      },
      formatter: StringFormatter.noNewlinesOrSurroundingWhitespace,
    );

    testPhases(
      'with an attribute',
      phases,
      {
        'a|foo_host.css': r'''
          :host[baz] {
            position: relative;
            margin-right: 3em;
          }
        '''
      },
      {
        'a|foo_host.css': r'''
          :host[baz] {
            position: relative;
          }
          :host-context([dir="ltr"])[baz] {
            margin-right: 3em;
          }
          :host-context([dir="rtl"])[baz] {
            margin-left: 3em;
          }
        '''
      },
      formatter: StringFormatter.noNewlinesOrSurroundingWhitespace,
    );

    testPhases(
      'skips near-matches',
      phases,
      {
        'a|foo_host.css': r'''
          :hostage {
            border-right: 10px;
          }
        '''
      },
      {
        'a|foo_host.css': r'''
          :host-context([dir="ltr"]) :hostage {
            border-right: 10px;
          }
          :host-context([dir="rtl"]) :hostage {
            border-left: 10px;
          }
        '''
      },
      formatter: StringFormatter.noNewlinesOrSurroundingWhitespace,
    );

    testPhases(
      'with existing :host-context',
      phases,
      {
        'a|foo_host.css': r'''
          :host-context(.foo) {
            position: fixed;
            right: 10px;
          }
        '''
      },
      {
        'a|foo_host.css': r'''
          :host-context(.foo) {
            position: fixed;
          }
          :host-context([dir="ltr"]) :host-context(.foo) {
            right: 10px;
          }
          :host-context([dir="rtl"]) :host-context(.foo) {
            left: 10px;
          }
        '''
      },
      formatter: StringFormatter.noNewlinesOrSurroundingWhitespace,
    );
  });
}

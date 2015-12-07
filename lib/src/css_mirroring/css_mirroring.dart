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
library scissors.src.css_mirroring.css_mirroring;

import 'package:barback/barback.dart';
import 'package:csslib/parser.dart' as css_parser;
import 'package:csslib/visitor.dart'
    show CssPrinter, RuleSet, StyleSheet, TreeNode, TreeOutput;
import 'package:source_maps/refactor.dart';
import 'package:source_span/source_span.dart';
import 'rtl_convertor.dart';

import '../utils/hacks.dart' as hacks;

import 'transformer.dart' show CssMirroringSettings;


/// Edits [transaction] to drop any CSS rule in [topLevels] that we're sure
/// is not referred to by any DOM node in [htmlTrees].
mirrorCssRules(
    Transform transform,
    TextEditTransaction transaction,
    TextEditTransaction transaction1,
    TextEditTransaction transaction2,
    CssMirroringSettings settings,
    SourceFile cssSourceFile,
    SourceFile cssSourceFile1) {
  hacks.useCssLib();

  final StyleSheet cssTree1 =
      new css_parser.Parser(cssSourceFile, transaction.original).parse();
  final StyleSheet cssTree2 =
  new css_parser.Parser(cssSourceFile, transaction.original).parse();

  generatecommon(transform, transaction, transaction1, transaction2, settings, cssSourceFile, cssSourceFile1, cssSourceFile1);

}

String _printCss(tree) =>
    (new CssPrinter()..visitTree(tree, pretty: true)).toString();


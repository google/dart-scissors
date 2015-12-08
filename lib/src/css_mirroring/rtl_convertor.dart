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
library scissors.src.css_pruning.rtl_convertor;

import 'dart:async';

import 'package:barback/barback.dart';
import 'package:csslib/parser.dart' as css_parser;
import 'package:csslib/visitor.dart'
    show CssPrinter, RuleSet, StyleSheet, TreeNode, TreeOutput, Declaration;
import 'package:source_maps/refactor.dart';
import 'package:source_span/source_span.dart';

import '../utils/hacks.dart' as hacks;
import 'transformer.dart' show CssMirroringSettings;


/// Edits [transaction] to drop any CSS rule in [topLevels] that we're sure
/// is not referred to by any DOM node in [htmlTrees].
generatecommon(Transform transform,
    TextEditTransaction transaction,
    TextEditTransaction transaction1,
    TextEditTransaction transaction2,
    CssMirroringSettings settings,
    SourceFile cssSourceFile,
    SourceFile cssSourceFile1,
    SourceFile cssSourceFile2) {
  hacks.useCssLib();

  bool ltrDirection = true;

  final StyleSheet cssTree =
  new css_parser.Parser(cssSourceFile, transaction.original).parse();
  List<TreeNode> topLevels = cssTree.topLevels;

  final StyleSheet cssTree1 = new css_parser.Parser(
      cssSourceFile1, transaction1.original).parse();
  List<TreeNode> topLevels1 = cssTree1.topLevels;

  createTransaction(TextEditTransaction t, bool common, bool fileid, direction) {
    for (int iTopLevel = 0; iTopLevel < topLevels.length; iTopLevel++) {
      var topLevel_tree1 = topLevels[iTopLevel];
      var topLevel_tree2 = topLevels1[iTopLevel];
      if (topLevel_tree1 is RuleSet) {
        print(topLevels[iTopLevel].span.text);
        var decls_tree1 = topLevel_tree1.declarationGroup.declarations;
        var decls_tree2 = topLevel_tree2.declarationGroup.declarations;
        List<int> startpoint = new List();
        List<int> endpoint = new List();
        bool saved = false;
        for (int iDecl = 0; iDecl < decls_tree1.length; iDecl++) {
          var declaration_tree1 = decls_tree1[iDecl];
          var declaration_tree2 = decls_tree2[iDecl];
          if (declaration_tree1 is Declaration) {
            if (common ? (declaration_tree1.span.text != declaration_tree2.span.text) : (declaration_tree1.span.text == declaration_tree2.span.text)) {
              var start =  fileid ? declaration_tree1.span.start.offset : declaration_tree2.span.start.offset;
              var end = fileid ? declaration_tree1.span.end.offset : declaration_tree2.span.end.offset;
              if (iDecl < decls_tree1.length - 1) {
                end = fileid ? decls_tree1[iDecl + 1].span.start.offset : decls_tree2[iDecl + 1].span.start.offset;
              } else {
                while (t.file.getText(end, end + 1) != '}') {
                  end++;
                }
              }
              startpoint.add(start);
              endpoint.add(end);
            }
            else {
              saved = true;
            }
          }
        }
        var ruleStartLocation = fileid ? topLevel_tree1.span.start.offset : topLevel_tree2.span.start.offset;
        var ruleEndLocation = fileid ? topLevel_tree1.span.end.offset : topLevel_tree2.span.end.offset;
        if (saved == false) {
          print('Rule getting deleted ${topLevels[iTopLevel].span.text}');
          if (iTopLevel < topLevels.length - 1) {
            t.edit(
                ruleStartLocation, fileid ? topLevels[iTopLevel + 1].span.start.offset : topLevels1[iTopLevel + 1].span.start.offset, '');
          }
          else {
            t.edit(
                ruleStartLocation, t.file.length, '');
          }
        }
        else {
          for (int i = 0; i < startpoint.length; i++) {
            t.edit(startpoint[i], endpoint[i], '');
          }
          if(!common)
            t.edit(ruleStartLocation, ruleEndLocation, ':host-context([dir="${direction}"]) ' + topLevels[iTopLevel].span.text);
        }
      }
    }
  }

  createTransaction(transaction, false, true, ltrDirection ? "ltr" : "rtl");
  createTransaction(transaction1, false, false, ltrDirection ? "rtl" : "ltr");
  createTransaction(transaction2, true, false, '');
}
String _printCss(tree) =>
    (new CssPrinter()..visitTree(tree, pretty: true)).toString();


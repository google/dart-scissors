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

import 'package:barback/barback.dart';
import 'package:csslib/parser.dart' as css_parser;
import 'package:csslib/visitor.dart'
    show RuleSet, StyleSheet, TreeNode, Declaration;
import 'package:source_maps/refactor.dart';
import 'package:source_span/source_span.dart';

import '../utils/hacks.dart' as hacks;
import 'transformer.dart' show CssMirroringSettings;

/// Edits transactions to generate orientation-neutral, non-flipped orientation-specific, flipped orientation-specific transactions.
generatecommon(Transform transform,
    TextEditTransaction transaction,
    TextEditTransaction transaction1,
    TextEditTransaction transaction2,
    CssMirroringSettings settings,
    SourceFile cssSourceFile,
    SourceFile cssSourceFile1) {
  hacks.useCssLib();

  /// Assuming default css to be left to right oriented.
  bool ltrDirection = true;

  /// Get topLevels for original css.
  final StyleSheet cssTree =
  new css_parser.Parser(cssSourceFile, transaction.original).parse();
  List<TreeNode> topLevels = cssTree.topLevels;

  /// Get topLevels for flipped css.
  final StyleSheet cssTree1 = new css_parser.Parser(
      cssSourceFile1, transaction1.original).parse();
  List<TreeNode> topLevels1 = cssTree1.topLevels;

  /// Modifes the Transaction depending on [common].
  /// If common is the true it generates css with orientation-neutral parts.
  /// Else generate css with orientation-specific parts depending the direction specified.
  modifyTransaction(TextEditTransaction trans, bool common, bool fileid,
      direction) {
    /// Iterate over topLevels.
    for (int iTopLevel = 0; iTopLevel < topLevels.length; iTopLevel++) {
      var topLevel_tree1 = topLevels[iTopLevel];
      var topLevel_tree2 = topLevels1[iTopLevel];
      /// Check if topLevel is a RuleSet.
      if (topLevel_tree1 is RuleSet) {
        // If topLevel is a RuleSet get declarationGroup in it.
        var decls_tree1 = topLevel_tree1.declarationGroup.declarations;
        var decls_tree2 = topLevel_tree2.declarationGroup.declarations;
        List<int> startpoint = new List();
        List<int> endpoint = new List();
        bool saved = false;
        // Iterate over Declarations in RuleSet.
        for (int iDecl = 0; iDecl < decls_tree1.length; iDecl++) {
          var declaration_tree1 = decls_tree1[iDecl];
          var declaration_tree2 = decls_tree2[iDecl];
          if (declaration_tree1 is Declaration) {
            if (common ? (declaration_tree1.span.text !=
                declaration_tree2.span.text) : (declaration_tree1.span.text ==
                declaration_tree2.span.text)) {
              var start = fileid
                  ? declaration_tree1.span.start.offset
                  : declaration_tree2.span.start.offset;
              var end = fileid
                  ? declaration_tree1.span.end.offset
                  : declaration_tree2.span.end.offset;
              if (iDecl < decls_tree1.length - 1) {
                end = fileid
                    ? decls_tree1[iDecl + 1].span.start.offset
                    : decls_tree2[iDecl + 1].span.start.offset;
              } else {
                while (trans.file.getText(end, end + 1) != '}') {
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
        var ruleStartLocation = fileid
            ? topLevel_tree1.span.start.offset
            : topLevel_tree2.span.start.offset;
        var ruleEndLocation = fileid
            ? topLevel_tree1.span.end.offset
            : topLevel_tree2.span.end.offset;
        /// Remove a Ruleset from transaction if all declarations in a RuleSet are to be removed.
        /// Else Remove declarations of a RuleSet from transaction.
        if (saved == false) {
          if (iTopLevel < topLevels.length - 1) {
            trans.edit(
                ruleStartLocation, fileid
                ? topLevels[iTopLevel + 1].span.start.offset
                : topLevels1[iTopLevel + 1].span.start.offset, '');
          }
          else {
            trans.edit(
                ruleStartLocation, trans.file.length, '');
          }
        }
        else {
          for (int i = 0; i < startpoint.length; i++) {
            trans.edit(startpoint[i], endpoint[i], '');
          }
          /// Add direction attribute to RuleId for direction-specific RuleSet.
          if (!common)
            trans.edit(ruleStartLocation, ruleEndLocation,
                ':host-context([dir="${direction}"]) ' +
                    topLevels[iTopLevel].span.text);
        }
      }
    }
  }

  modifyTransaction(transaction, false, true, ltrDirection ? "ltr" : "rtl");
  modifyTransaction(transaction1, false, false, ltrDirection ? "rtl" : "ltr");
  modifyTransaction(transaction2, true, false, '');
}


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

import 'package:csslib/parser.dart' show parse;
import 'package:csslib/visitor.dart'
    show RuleSet, StyleSheet, TreeNode, Declaration;
import 'package:quiver/check.dart';
import 'package:source_maps/refactor.dart';
import 'package:source_span/source_span.dart';

import 'cssjanus_runner.dart';
import 'transformer.dart' show CssMirroringSettings, Direction;



generateBidiCss (String sourceData, String sourceFileId, CssMirroringSettings settings) async {
  String nativeDirection = settings.cssDirection.value;
  String originalSourceData = sourceData;
  String flippedSourceData = await runCssJanus(sourceData, settings);

  // Get Treenodes for original css.
  List<TreeNode> originalTopLevels = _getCssTopLevels(originalSourceData);
  // Get Treenodes for flipped css.
  List<TreeNode> flippedTopLevels = _getCssTopLevels(flippedSourceData);

  // Generate Transactions.
  TextEditTransaction generateTransaction(String sourceData) =>
      new TextEditTransaction(sourceData, new SourceFile(sourceData, url: sourceFileId));
  TextEditTransaction orientationNeutralTransaction = generateTransaction(sourceData);
  TextEditTransaction orientationSpecificTransaction = generateTransaction(sourceData);
  TextEditTransaction flippedOrientationSpecificTransaction = generateTransaction(flippedSourceData);

  modifyTransaction(TextEditTransaction trans, bool isOrientationNeutral,
      bool useOriginalSource, Direction dir) {
    /// Iterate over topLevels.
    for (int iTopLevel = 0; iTopLevel < originalTopLevels.length; iTopLevel++) {
      var originalTopLevelNode = originalTopLevels[iTopLevel];
      var flippedTopLevelNode = flippedTopLevels[iTopLevel];

      /// Check if topLevel is a RuleSet.
      if (isRuleSet(originalTopLevelNode, flippedTopLevelNode)) {
        // If topLevel is a RuleSet get declarationGroup in it.
        var originalRuleSetDecls = originalTopLevelNode.declarationGroup
            .declarations;
        var flippedRuleSetDecls = flippedTopLevelNode.declarationGroup
            .declarations;

        bool isSomeDeclarationSaved = false;
        var startPoint = <int>[];
        var endPoint = <int>[];

        // Iterate over Declarations in RuleSet.
        for (int iDecl = 0; iDecl < originalRuleSetDecls.length; iDecl++) {
          var originalDeclarationNode = originalRuleSetDecls[iDecl];
          var flippedDeclarationNode = flippedRuleSetDecls[iDecl];

          var start;
          var end;

          if (isDeclaration(originalDeclarationNode, flippedDeclarationNode)) {
            if (deleteDeclaration(isOrientationNeutral, originalDeclarationNode,
                flippedDeclarationNode)) {

              setStartEnd(span) {
                start = span.start.offset;
                end = span.end.offset;
                if (iDecl < originalRuleSetDecls.length - 1) {
                  end = useOriginalSource
                      ? originalRuleSetDecls[iDecl + 1].span.start.offset
                      : flippedRuleSetDecls[iDecl + 1].span.start.offset;
                } else {
                  end = getEndOfRuleSet(trans, end);
                }
              }

              setStartEnd(useOriginalSource
                  ? originalDeclarationNode.span
                  : flippedDeclarationNode.span);
              startPoint.add(start);
              endPoint.add(end);
            }
            else {
              isSomeDeclarationSaved = true;
            }
          }
        }
        var ruleStartLocation;
        var ruleEndLocation;
        setRuleStartEnd(span) {
          ruleStartLocation = span.start.offset;
          ruleEndLocation = span.end.offset;
        }
        setRuleStartEnd(
            useOriginalSource ? originalTopLevelNode.span : flippedTopLevelNode
                .span);

        /// Remove a Ruleset from transaction if all declarations in a RuleSet are to be removed.
        /// Else Remove declarations of a RuleSet from transaction.
        if (isSomeDeclarationSaved == true) {
          for (int i = 0; i < startPoint.length; i++) {
            trans.edit(startPoint[i], endPoint[i], '');
          }

          /// Add direction attribute to RuleId for direction-specific RuleSet.
          if (!isOrientationNeutral) {
            trans.edit(ruleStartLocation, ruleEndLocation,
                ':host-context([dir="${dir}"]) ' +
                    originalTopLevels[iTopLevel].span.text);
          }
        }
        else {
          var end = iTopLevel < originalTopLevels.length - 1
              ? (useOriginalSource ? originalTopLevels[iTopLevel + 1].span.start
              .offset : flippedTopLevels[iTopLevel + 1].span.start.offset)
              : trans.file.length;
          trans.edit(ruleStartLocation, end, '');
        }
      }
    }
  }

  modifyTransaction(orientationNeutralTransaction, true, true, Direction.ltr);
  modifyTransaction(orientationSpecificTransaction, false, true, Direction.ltr);
  modifyTransaction(flippedOrientationSpecificTransaction, false, false, Direction.rtl);
  return (orientationNeutralTransaction.commit()..build('')).text + '\n' + (orientationSpecificTransaction.commit()..build('')).text + '\n' + (flippedOrientationSpecificTransaction.commit()..build('')).text;
}

List<TreeNode> _getCssTopLevels(String path) =>
     parse(path).topLevels;

bool deleteDeclaration(bool getOrientationNeutral,Declaration originalDeclarationNode,Declaration flippedDeclarationNode) =>
  getOrientationNeutral ? originalDeclarationNode.span.text != flippedDeclarationNode.span.text : originalDeclarationNode.span.text == flippedDeclarationNode.span.text;

bool isRuleSet(var originalTopLevelNode, var flippedTopLevelNode) {
  return (originalTopLevelNode is RuleSet) && (flippedTopLevelNode is RuleSet);
}

bool isDeclaration(var originalDeclarationNode, var flippedDeclarationNode) {
  return (originalDeclarationNode is Declaration) && (flippedDeclarationNode is Declaration);
}

getEndOfRuleSet(TextEditTransaction trans, var end) {
  //                indexOF('}')
  // .foo { float: left /* becaue `foo: right;` would not work */; /* Haha { } */ }
  while (trans.file.getText(end, end + 1) != '}') {
    end++;
  }
  return end;
}
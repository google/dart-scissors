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

import 'package:csslib/parser.dart' show parse;
import 'package:csslib/visitor.dart'
    show RuleSet, StyleSheet, TreeNode, Declaration, MediaDirective;
import 'package:quiver/check.dart';
import 'package:source_maps/refactor.dart';
import 'package:source_span/source_span.dart';

import 'cssjanus_runner.dart';
import '../utils/enum_parser.dart';
import 'transformer.dart' show CssMirroringSettings, Direction;

enum RetensionMode {
  keepBidiNeutral,
  keepOriginalBidiSpecific,
  keepFlippedBidiSpecific
}


/// GenerateBidiCss generates a Css which comprises of Orientationn Neutral, Orientation Specific and Flipped Orientation Specific parts.
/// Its takes a css string, sourcefile name, nativeDirection of input css and path to cssjanus.
/// It generates a flipped version of the input css by passing it to cssJanus.
/// Toplevels of the originalCss and flippedCss are extracted. It iterates over these topLevels to and checks if they are of the type RuleSet.
/// If they are of type rule set it iterates over declarations in them.
/// Depending on the mode of execution which could be [keepBidiNeutral], [keepOriginalBidiSpecific], [keepFlippedBidiSpecific],
/// it checks if the declaration is to be removed and stores their [start] and [end] points.
/// It then removes the entire ruleSet if all the declarations in it are to be removed. Otherwise it removes the declarations.
/// How to pass function.
Future<String> generateBidiCss(String sourceData, String sourceFileId,
    Direction nativeDirection, String cssJanusPath) async {
  String flippedSourceData = await runCssJanus(sourceData, cssJanusPath);

  // Get Treenodes for original css.
  List<TreeNode> originalTopLevels = _getCssTopLevels(sourceData);
  // Get Treenodes for flipped css.
  List<TreeNode> flippedTopLevels = _getCssTopLevels(flippedSourceData);

  print(sourceFileId);
  // Generate Transactions.
  TextEditTransaction makeTransaction(String original) =>
      new TextEditTransaction(original, new SourceFile(original, url: sourceFileId));

  var orientationNeutralTransaction = makeTransaction(sourceData);
  var orientationSpecificTransaction = makeTransaction(sourceData);
  var flippedOrientationSpecificTransaction = makeTransaction(flippedSourceData);

  //dropCssDeclarations(tr, OrientationSensitivity kindOfDeclToDrop, ...)
  modifyTransaction(TextEditTransaction trans, RetensionMode mode, String dir) {
    /// Iterate over topLevels.
    for (int iTopLevel = 0; iTopLevel < originalTopLevels.length; iTopLevel++) {
      var originalTopLevel = originalTopLevels[iTopLevel];
      var flippedTopLevel = flippedTopLevels[iTopLevel];

      /// Check if topLevel is a RuleSet.
      if (originalTopLevel is RuleSet && flippedTopLevel is RuleSet) {
        // If topLevel is a RuleSet get declarationGroup in it.
        var originalDecls = originalTopLevel.declarationGroup.declarations;
        var flippedDecls = flippedTopLevel.declarationGroup.declarations;

        bool didRetainDecls = false;
        var startPoints = <int>[];
        var endPoints = <int>[];

        // Iterate over Declarations in RuleSet and store start and end points of declarations to be removed.
        for (int iDecl = 0; iDecl < originalDecls.length; iDecl++) {
          var originalDecl = originalDecls[iDecl];
          var flippedDecl = flippedDecls[iDecl];

          if (originalDecl is Declaration && flippedDecl is Declaration) {
            // If the mode is [RetensionMode.keepBidiNeutral] then declarations which are different in original and flipped css need to be dropped(Neutral declarations needs to be kept).
            // Otherwise declaration  which are common need to be dropped.
            bool isDroppableDeclaration(RetensionMode mode, Declaration originalDeclarationNode, Declaration flippedDeclarationNode) =>
                mode == RetensionMode.keepBidiNeutral
                    ? originalDeclarationNode.span.text !=
                    flippedDeclarationNode.span.text
                    : originalDeclarationNode.span.text ==
                    flippedDeclarationNode.span.text;

            if (isDroppableDeclaration(mode, originalDecl, flippedDecl)) {
              setStartEnd(decls) {
                var currentDecl = decls[iDecl];
                int start = currentDecl.span.start.offset;
                int end;
                // TODO comment
                if (iDecl < originalDecls.length - 1) {
                  var nextDecl = decls[iDecl + 1];
                  end = nextDecl.span.start.offset;
                } else {
                  end = _getEndOfRuleSet(trans, currentDecl.span.end.offset);
                }
                startPoints.add(start);
                endPoints.add(end);
              }
              setStartEnd(mode == RetensionMode.keepFlippedBidiSpecific ? flippedDecls : originalDecls);
            }
            else {
              didRetainDecls = true;
            }
          }
          else {
            checkState(
                originalTopLevel.runtimeType == flippedTopLevel.runtimeType);
            // what of not declaration.
            // TODO inline test here and check if expectation shattererd
          }
        }

        var ruleStartLocation;
        var ruleEndLocation;
        setRuleStartEnd(span) {
          ruleStartLocation = span.start.offset;
          ruleEndLocation = span.end.offset;
        }
        setRuleStartEnd(
            mode == RetensionMode.keepFlippedBidiSpecific
                ? flippedTopLevel.span
                : originalTopLevel.span);
        /// Remove a Ruleset from transaction if all declarations in a RuleSet are to be removed.
        /// Else Remove declarations of a RuleSet from transaction.
        if (didRetainDecls) {
          removeDeclarations() {
            for (int i = 0; i < startPoints.length; i++) {
              trans.edit(startPoints[i], endPoints[i], '');
            }
          }
          removeDeclarations();

          /// Add direction attribute to RuleId for direction-specific RuleSet.
          if (mode != RetensionMode.keepBidiNeutral) {
            trans.edit(ruleStartLocation, ruleEndLocation,
                ':host-context([dir="${dir}"]) ' +
                    originalTopLevels[iTopLevel].span.text);
          }
        }
        else {
          removeRule() {
            var end = iTopLevel < originalTopLevels.length - 1
                ? (mode == RetensionMode.keepFlippedBidiSpecific
                ? flippedTopLevels[iTopLevel + 1].span.start.offset
                : originalTopLevels[iTopLevel + 1].span.start.offset)
                : trans.file.length;
            trans.edit(ruleStartLocation, end, '');
          }
          removeRule();
        }
      } else {
        checkState(originalTopLevel.runtimeType == flippedTopLevel.runtimeType);
        // TODO: handle non-RuleSets...
      }
    }
  }


  modifyTransaction(orientationNeutralTransaction, RetensionMode.keepBidiNeutral, '');
  modifyTransaction(orientationSpecificTransaction, RetensionMode.keepOriginalBidiSpecific, enumName(nativeDirection));
  modifyTransaction(flippedOrientationSpecificTransaction, RetensionMode.keepFlippedBidiSpecific, nativeDirection == Direction.ltr ? 'rtl' : 'ltr');
  return (orientationNeutralTransaction.commit()..build('')).text + '\n' + (orientationSpecificTransaction.commit()..build('')).text + '\n' + (flippedOrientationSpecificTransaction.commit()..build('')).text;
}

List<TreeNode> _getCssTopLevels(String path) =>
    parse(path).topLevels;

// todo comment
// todo private helpers throughout
// todo return types
int _getEndOfRuleSet(TextEditTransaction trans, int /*fromIndex*/end) {
  //                indexOF('}')
  // .foo { float: left /* becaue `foo: right;` would not work */; /* Haha { } */ }
  while (trans.file.getText(end, end + 1) != '}') {
    end++;
  }
  return end;
}
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
library scissors.src.css_mirroring.bidi_css_gen;

import 'dart:async';

import 'package:csslib/parser.dart' show parse;
import 'package:csslib/visitor.dart'
    show RuleSet, StyleSheet, TreeNode, Declaration, MediaDirective, HostDirective, PageDirective, CharsetDirective, FontFaceDirective, ImportDirective, KeyFrameDirective, NamespaceDirective;
import 'package:quiver/check.dart';
import 'package:source_maps/refactor.dart';
import 'package:source_span/source_span.dart';

import '../utils/enum_parser.dart';
import 'transformer.dart' show CssMirroringSettings, Direction, flipDirection;

enum RetensionMode {
  keepBidiNeutral,  /// to keep parts of css which is direction independent eg: color and width
  keepOriginalBidiSpecific, /// to keep direction dependent parts of original css eg: margin.
  keepFlippedBidiSpecific /// to keep direction dependent parts of flipped css.
}

/// GenerateBidiCss generates a Css which comprises of Orientation Neutral, Orientation Specific and Flipped Orientation Specific parts.
/// Eg: foo {
///           color: red;
///           margin-left: 10px;
///         }
/// gets converted to
///     foo {
///           color: red;                       /// Orientation Neutral (Independent of direction)
///         }
///
///    :host-context([dir="ltr"]) foo {
///           margin-left: 10px;                /// Orientation Specific (Orientation specific parts in original css)
///         }
///
///    :host-context([dir="rtl"]) foo {
///           margin-right: 10px;               /// Flipped Orientation Specific (Orientation specific parts in flipped css)
///        }
///
/// Its takes a css string, sourcefile name, nativeDirection of input css and path to cssjanus.
/// It generates a flipped version of the input css by passing it to cssJanus.
/// Eg: passing foo {
///           color: red;
///           margin-left: 10px;          /// will be used as Original css
///         }
/// to css janus returns
///     foo {
///           color: red;
///           margin-right: 10px;         /// will be used as flipped css.
///         }
///
/// Next we create three transactions(css strings)
///     1) Orientation Neutral: It is made from original css string. Direction dependent parts will be removed from it to keep only neutral parts.
///               eg: Initially contains foo { color: red; margin-left: 10px;} and will get modified to foo { color: red;}
///     2) Orientation specific: It is made from original css string.
///                              Direction independent parts will be removed from it to keep only direction dependent parts of original css.
///               eg: Initially contains foo { color: red; margin-left: 10px;} and will get modified to :host-context([dir="ltr"]) foo { margin-left: 10px;}
///     3) Flipped Orientation specific: It is made from flipped css string.
///                              Direction independent parts will be removed from it to keep only direction dependent parts of original css.
///               eg: Initially contains foo { color: red; margin-right: 10px;} and will get modified to :host-context([dir="rtl"]) foo { margin-right: 10px;}
///
/// So for each of these transactions we extract toplevels of the originalCss and flippedCss. It iterates over these topLevels.
/// If it is of type rule set
///     Iterates over declarations in them.
///     Depending on the mode of execution which could be [keepBidiNeutral], [keepOriginalBidiSpecific], [keepFlippedBidiSpecific],
///     check if the declaration is to be removed and store their start and end points.
///     Now if only some declarations have to be removed, remove them using their start and end points already stored.
///     And if all declarations in a ruleset are to be removed, Remove the ruleset (No need to keep empty rule)
///
/// If it is of type Media or Host Directive
///   eg:
///    @media screen and (min-width: 401px) {
///                  foo { margin-left: 13px }             /// Media Directive containing ruleset foo
///                  }
///   Directive --> RuleSets --> Declarations
///   Pick a ruleset:
///     stores removable declarations in it ->
///     If only some of the declaration have to be removed -> remove them from transaction.
///     If all declarations in ruleset removable -> store start and end of rule set(dont edit transaction because if all rulesets of directive have to be deleted then we will delete directive itself)
///   If only some rulesets in Directive have to be removed -> remove them using store start and end points
///   If all the rulesets have to be removed -> remove the Directive itself.
///
/// If it is a Direction Independent Directive
///   eg:
///     @charset "UTF-8";                                 /// Charset Directive
///     @namespace url(http://www.w3.org/1999/xhtml);     /// Namespace Directive
///  Keep it in one of the transaction and remove it from other two (Here we are keeping it in Orientation Neutral transaction).
///
/// We then combine these transactions to get the expected output css.

typedef Future<String> CssFlipper(String src);

class _PendingRemovals {
  final String source;
  final List<TreeNode> _topLevels;
  final TextEditTransaction _transaction;
  // List to contain start and end location of declarations in transaction.
  var _declStartPoints = <int>[];
  var _declEndPoints = <int>[];

  _PendingRemovals(TextEditTransaction trans, this._topLevels)
      : _transaction = trans,
        source = trans.file.getText(0);

  void addDeclRemoval(int start, int end) {
    _declStartPoints.add(start);
    _declEndPoints.add(end);
  }

  void commitDeclarations() {
    for (int iDecl = 0; iDecl < _declStartPoints.length; iDecl++)
      _transaction.edit(_declStartPoints[iDecl], _declEndPoints[iDecl], '');
    _declStartPoints.clear();
    _declEndPoints.clear();
  }
}

class BidiCssGenerator {
  final String _originalCss;
  final String _flippedCss;
  final List<TreeNode> _originalTopLevels;
  final List<TreeNode> _flippedTopLevels;
  final Direction _nativeDirection;

  TextEditTransaction _orientationNeutralTransaction;
  TextEditTransaction _orientationSpecificTransaction;
  TextEditTransaction _flippedOrientationSpecificTransaction;

  BidiCssGenerator._(String originalCss, String flippedCss, String cssSourceId, this._nativeDirection)
      : _originalCss = originalCss,
        _flippedCss = flippedCss,
        _originalTopLevels = parse(originalCss).topLevels,
        _flippedTopLevels = parse(flippedCss).topLevels,
        _orientationNeutralTransaction = _makeTransaction(originalCss, cssSourceId),
        _orientationSpecificTransaction = _makeTransaction(originalCss, cssSourceId),
        _flippedOrientationSpecificTransaction = _makeTransaction(flippedCss, cssSourceId);

  static build(
      String originalCss, String cssSourceId, Direction nativeDirection, CssFlipper cssFlipper) async {
    return new BidiCssGenerator._(originalCss, await cssFlipper(originalCss), cssSourceId, nativeDirection);
  }


  /// main function which returns the bidirectional css.
  String getOutputCss() {
    _modifyTransactions();
    return _joinTransactions();
  }

  /// Makes transaction from input string.
  static TextEditTransaction _makeTransaction(String inputCss, String url) =>
      new TextEditTransaction(inputCss, new SourceFile(inputCss, url: url));

  /// Join the transactions to generate output transaction.
  String _joinTransactions() {
    return (_orientationNeutralTransaction.commit()
      ..build('')).text + '\n' + (_orientationSpecificTransaction.commit()
      ..build('')).text + '\n' +
        (_flippedOrientationSpecificTransaction.commit()
          ..build('')).text;
  }

  /// Modifies the transactions to contain only the desired parts.
  _modifyTransactions() {
    _editTransaction(_orientationNeutralTransaction, RetensionMode.keepBidiNeutral, _nativeDirection);
    _editTransaction(_orientationSpecificTransaction, RetensionMode.keepOriginalBidiSpecific, _nativeDirection);
    _editTransaction(_flippedOrientationSpecificTransaction, RetensionMode.keepFlippedBidiSpecific, flipDirection(_nativeDirection));
  }

  /// Takes transaction to edit, the retension mode which defines which part to retain and the direction of the output css.
  /// Modifies the transaction depending on the input parameters.
  _editTransaction(TextEditTransaction trans, RetensionMode mode, Direction targetDirection) {

    /// Iterate over topLevels.
    for (int iTopLevel = 0; iTopLevel < _originalTopLevels.length; iTopLevel++) {
      var originalTopLevel = _originalTopLevels[iTopLevel];
      var flippedTopLevel = _flippedTopLevels[iTopLevel];
      var removals = new _PendingRemovals(trans, mode == RetensionMode.keepFlippedBidiSpecific ? _flippedTopLevels : _originalTopLevels);

      if (originalTopLevel is RuleSet && flippedTopLevel is RuleSet) {
        _editRuleSet(removals, mode, targetDirection, iTopLevel, removals.source.length);
      }
      else if(originalTopLevel.runtimeType == flippedTopLevel.runtimeType && (originalTopLevel is MediaDirective || originalTopLevel is HostDirective)) {
        TreeNode usedDirective = mode == RetensionMode.keepFlippedBidiSpecific ? flippedTopLevel : originalTopLevel;
        _editDirectives(removals, usedDirective, originalTopLevel.rulesets, flippedTopLevel.rulesets, mode, targetDirection);
      }
      else if(originalTopLevel.runtimeType == flippedTopLevel.runtimeType && _isDirectionIndependent(originalTopLevel)) {
        if (mode != RetensionMode.keepBidiNeutral) {
          _removeRuleSet(removals, iTopLevel);
        }
      }
      else {
        checkState(originalTopLevel.runtimeType == flippedTopLevel.runtimeType);
        // TODO: throw sass file error
        // TODO: handle pagedirective and key frame animation.
      }
    }
  }

  /// Edit the topLevel Ruleset.
  /// It takes transaction, the topLevels of original and flipped css, Retantion mode, Direction of output css, the index of current topLevel and end of parent of topLevel.
   _editRuleSet(_PendingRemovals removals, RetensionMode mode, Direction targetDirection, int iTopLevel, int parentEnd) {
    _storeRemovableDeclarations(removals, _originalTopLevels, _flippedTopLevels, mode, iTopLevel);
    if (_isRuleRemovable(removals, _originalTopLevels[iTopLevel])) {
      _removeRuleSet(removals, iTopLevel);
    }
    else {
      removals.commitDeclarations();
      /// Add direction attribute to RuleId for direction-specific RuleSet.
      if (mode != RetensionMode.keepBidiNeutral) {
        _appendDirectionToRuleSet(removals, removals._topLevels[iTopLevel], targetDirection);
      }
    }
  }

  _editDirectives(_PendingRemovals removals, var usedDirective, List<RuleSet> originalRuleSets, List<RuleSet> flippedRuleSets, RetensionMode mode, Direction targetDirection) {
    var _ruleStartPoints = <int>[];
    var _ruleEndPoints = <int>[];
    for(int iRuleSet = 0; iRuleSet < originalRuleSets.length; iRuleSet++) {
        _storeRemovableDeclarations(removals, originalRuleSets, flippedRuleSets, mode, iRuleSet);
        if(_isRuleRemovable(removals, originalRuleSets[iRuleSet])) {
          var startOffset = _getRuleSetStart(originalRuleSets[iRuleSet]);
          var endOffset = _getRuleSetEnd(usedDirective.rulesets, iRuleSet, usedDirective.span.end.offset);
          _ruleStartPoints.add(startOffset);
          _ruleEndPoints.add(endOffset);
        }
      else {
          removals.commitDeclarations();
          if (mode != RetensionMode.keepBidiNeutral) {
            _appendDirectionToRuleSet(removals, usedDirective.rulesets[iRuleSet], targetDirection);
          }
        }
    }
    if(_ruleStartPoints.length == originalRuleSets.length ) { // All rules are to be deleted
      _removeDirective(removals, usedDirective);
    }
    else {
      _removeStoredRules(removals, _ruleStartPoints, _ruleEndPoints);
    }
  }

  _storeRemovableDeclarations(_PendingRemovals removals, var originalTopLevels, var flippedTopLevels, RetensionMode mode, int iTopLevel) {
    var originalDecls = originalTopLevels[iTopLevel].declarationGroup.declarations;
    var flippedDecls = flippedTopLevels[iTopLevel].declarationGroup.declarations;

    /// Iterate over Declarations in RuleSet and store start and end points of declarations to be removed.
    for (int iDecl = 0; iDecl < originalDecls.length; iDecl++) {
      if (originalDecls[iDecl] is Declaration && flippedDecls[iDecl] is Declaration) {
        if (shouldRemoveDecl(mode, originalDecls[iDecl], flippedDecls[iDecl])) {
          var decls = mode == RetensionMode.keepFlippedBidiSpecific ? flippedDecls : originalDecls;
          removals.addDeclRemoval(decls[iDecl].span.start.offset, _getDeclarationEnd(removals.source, iDecl, originalDecls, decls));
        }
      }
      else {
        checkState(originalTopLevels[iTopLevel].runtimeType == flippedTopLevels[iTopLevel].runtimeType);
      }
    }
  }

  _appendDirectionToRuleSet(_PendingRemovals removals, RuleSet ruleSet, Direction targetDirection) {
    removals._transaction.edit(ruleSet.span.start.offset, ruleSet.span.end.offset,
        ':host-context([dir="${enumName(targetDirection)}"]) ' +
            ruleSet.span.text);
  }

  _removeStoredRules(_PendingRemovals removals, List<int> ruleStartPoints, List<int> ruleEndPoints) {
    for(int iPoint = 0; iPoint < ruleStartPoints.length; iPoint++) {
      removals._transaction.edit(ruleStartPoints[iPoint], ruleEndPoints[iPoint], '');
    }
  }
  /// Removes a rule from the transaction.
  _removeRuleSet(_PendingRemovals removals, int iTopLevel) {
    removals._transaction.edit(_getRuleSetStart(removals._topLevels[iTopLevel]), _getRuleSetEnd(removals._topLevels, iTopLevel, removals.source.length), '');
  }

  _removeDirective(_PendingRemovals removals, TreeNode topLevel) {
    removals._transaction.edit(_getRuleSetStart(topLevel) , topLevel.span.end.offset, '');
  }

  static int _getRuleSetStart(TreeNode node) {
    if(node is RuleSet)
      return node.span.start.offset;
    // In case of Directives since the node span start does not include '@' so additional -1 is required.
    return node.span.start.offset - 1;
  }

  static int _getRuleSetEnd(List<RuleSet> ruleSets, int iTopLevel, int parentEnd) {
    var end = iTopLevel < ruleSets.length - 1
        ? _getRuleSetStart(ruleSets[iTopLevel + 1])
        : parentEnd;
    return end;
  }

  static int _getDeclarationEnd(String source, int iDecl, var originalDecls, var decls) {
    if (iDecl < originalDecls.length - 1) {
      return decls[iDecl + 1].span.start.offset;
    } else {
      int fileLength = source.length;
      int fromIndex = decls[iDecl].span.end.offset;
      try {
        while (fromIndex + 1 < fileLength) {
          if (source.substring(fromIndex, fromIndex + 2) == '/*') {
            while (source.substring(fromIndex, fromIndex + 2) != '*/') {
              fromIndex++;
            }
          }
          else if (source[fromIndex + 1] == '}')
            return fromIndex + 1;
          fromIndex++;
        }
      }
      catch (exception, stackTrace) {
        print('Invalid Css');
      }
    }
  }

  bool _isRuleRemovable(_PendingRemovals removals, var originalTopLevel) =>
      removals._declStartPoints.length == originalTopLevel.declarationGroup.declarations.length;

  /// Checks if a topLevel is direction independent.
  bool _isDirectionIndependent(var originalTopLevel) {
    List _directionIndependentDirectives = [
      CharsetDirective,
      FontFaceDirective,
      ImportDirective,
      KeyFrameDirective,
      NamespaceDirective
    ];
    if(_directionIndependentDirectives.contains(originalTopLevel.runtimeType))
      return true;
    return false;
  }

  bool shouldRemoveDecl(RetensionMode mode, Declaration original, Declaration flipped) {
    var isEqual = _areDeclarationsEqual(original, flipped);
    return mode == RetensionMode.keepBidiNeutral ? !isEqual : isEqual;
  }

}
bool _areDeclarationsEqual(Declaration a, Declaration b) =>
    a.span.text == b.span.text;
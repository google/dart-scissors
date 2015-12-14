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
import 'cssjanus_runner.dart';
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
// TODO pass cssjanus function instead of path

class BidiCssGenerator {
  String _originalCss;
  String _flippedCss;
  String _cssSourceId;
  List<TreeNode> _originalTopLevels;
  List<TreeNode> _flippedTopLevels;
  Direction _nativeDirection;
  String _cssJanusPath;
  TextEditTransaction _orientationNeutralTransaction;
  TextEditTransaction _orientationSpecificTransaction;
  TextEditTransaction _flippedOrientationSpecificTransaction;
  var _originalDecl;
  var _flippedDecl;
  var startPoints = <int>[];
  var endPoints = <int>[];
  var didRetainDecls;
  List _directionIndependentDirectives = [CharsetDirective, FontFaceDirective, ImportDirective, KeyFrameDirective, NamespaceDirective];

  /// Constructor
  BidiCssGenerator(this._originalCss, this._cssSourceId, this._nativeDirection,
      this._cssJanusPath);

  /// main function which returns the bidirectional css.
  Future<String> getOutputCss() async {
    await _generateFlippedCss();
    _setupTransaction();
    _extractTopLevels();
    _modifyTransactions();
    String result = _joinTransactions();
    return result;
  }

  /// Populates [_flippedCss] with flipped css string.
  _generateFlippedCss() async {
    _flippedCss = await runCssJanus(_originalCss, _cssJanusPath);
  }

  /// Sets up 3 Transactions:
  ///  OrientationNeutral that will contain the orientation invarient parts.
  ///  OrientationSpecific that will contain the orientation specific parts from original css.
  ///  FlippedOrientationSpecific that will will contain the orientation specific parts from flipped css
  _setupTransaction() {
    _orientationNeutralTransaction = _makeTransaction(_originalCss);
    _orientationSpecificTransaction = _makeTransaction(_originalCss);
    _flippedOrientationSpecificTransaction = _makeTransaction(_flippedCss);
  }

  /// Makes transaction from input string.
  TextEditTransaction _makeTransaction(String inputCss) =>
      new TextEditTransaction(
          inputCss, new SourceFile(inputCss, url: _cssSourceId));

  /// Extracts topLevels from original and flipped css.
  _extractTopLevels() {
    _originalTopLevels = parse(_originalCss).topLevels;
    _flippedTopLevels = parse(_flippedCss).topLevels;
  }

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
    _editTransaction(
        _orientationNeutralTransaction, RetensionMode.keepBidiNeutral, '');
    _editTransaction(
        _orientationSpecificTransaction, RetensionMode.keepOriginalBidiSpecific,
        enumName(_nativeDirection));
    _editTransaction(_flippedOrientationSpecificTransaction,
        RetensionMode.keepFlippedBidiSpecific,
        _nativeDirection == Direction.ltr ? 'rtl' : 'ltr');
  }

  /// Takes transaction to edit, the retension mode which defines which part to retain and the direction of the output css.
  /// Modifies the transaction depending on the input parameters.
  _editTransaction(TextEditTransaction trans, RetensionMode mode, String dir) {
    /// Iterate over topLevels.
    for (int iTopLevel = 0; iTopLevel < _originalTopLevels.length;
    iTopLevel++) {
      var originalTopLevel = _originalTopLevels[iTopLevel];
      var flippedTopLevel = _flippedTopLevels[iTopLevel];

      /// Check if topLevel is a RuleSet.
      if (originalTopLevel is RuleSet && flippedTopLevel is RuleSet) {
        _editRuleSet(trans, _originalTopLevels, _flippedTopLevels, mode, dir, iTopLevel, trans.file.length);
      }
      else if (originalTopLevel is MediaDirective && flippedTopLevel is MediaDirective){
        _editMediaDirective(trans, originalTopLevel, flippedTopLevel, mode, dir, iTopLevel);
      }
      else if (originalTopLevel is HostDirective && flippedTopLevel is HostDirective){
        _editHostDirective(trans, originalTopLevel, flippedTopLevel, mode, dir, iTopLevel);
      }
      else if(originalTopLevel.runtimeType == flippedTopLevel.runtimeType && _isDirectionIndependent(originalTopLevel)) {
        _editDirectionIndependentDirectives(trans, _originalTopLevels, _flippedTopLevels, mode, iTopLevel, trans.file.length);
      }
      else {
        checkState(originalTopLevel.runtimeType == flippedTopLevel.runtimeType);
        // TODO: throw sass file error
        // TODO: handle non-RuleSets...
        // TODO: handle pagedirective and key frame animation.
      }
    }
  }

  /// Edit the topLevel Ruleset.
  /// It takes transaction, the topLevels of original and flipped css, Retantion mode, Direction of output css, the index of current topLevel and end of parent of topLevel.
  _editRuleSet(TextEditTransaction trans, var originalTopLevels, var flippedTopLevels, RetensionMode mode, String dir,
      int iTopLevel, int parentEnd) {
    /// If topLevel is a RuleSet get declarationGroup in it.
    var originalDecls = originalTopLevels[iTopLevel].declarationGroup.declarations;
    var flippedDecls = flippedTopLevels[iTopLevel].declarationGroup.declarations;

    didRetainDecls = false;
    startPoints.clear();
    endPoints.clear();
    /// Iterate over Declarations in RuleSet and store start and end points of declarations to be removed.
    for (int iDecl = 0; iDecl < originalDecls.length; iDecl++) {
      _originalDecl = originalDecls[iDecl];
      _flippedDecl = flippedDecls[iDecl];
      if (_originalDecl is Declaration && _flippedDecl is Declaration) {
        _editDeclaration(trans, originalDecls, flippedDecls, mode, iDecl);
      }
      else {
        checkState(originalTopLevels[iTopLevel].runtimeType == flippedTopLevels[iTopLevel].runtimeType);
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
            ? flippedTopLevels[iTopLevel].span
            : originalTopLevels[iTopLevel].span);

    /// Remove a Ruleset from transaction if all declarations in a RuleSet are to be removed.
    /// Else Remove declarations of a RuleSet from transaction.
    if (didRetainDecls) {
      _removeDeclarations(trans);
      /// Add direction attribute to RuleId for direction-specific RuleSet.
      if (mode != RetensionMode.keepBidiNeutral) {
        trans.edit(ruleStartLocation, ruleEndLocation,
            ':host-context([dir="${dir}"]) ' +
                originalTopLevels[iTopLevel].span.text);
      }
    }
    else {
      _removeRule(trans, originalTopLevels, flippedTopLevels, mode, iTopLevel, ruleStartLocation, parentEnd);
    }
  }

  /// Populates [startPoints] and [endPoints] with start and end points of declarations to be removed.
  _editDeclaration(TextEditTransaction trans, var originalDecls,
      var flippedDecls, RetensionMode mode, int iDecl) {
    // If the mode is [RetensionMode.keepBidiNeutral] then declarations which are different in original and flipped css need to be dropped(Neutral declarations needs to be kept).
    // Otherwise declaration  which are common need to be dropped.
    bool isDroppableDeclaration(RetensionMode mode,
        Declaration originalDeclarationNode,
        Declaration flippedDeclarationNode) =>
        mode == RetensionMode.keepBidiNeutral
            ? originalDeclarationNode.span.text !=
            flippedDeclarationNode.span.text
            : originalDeclarationNode.span.text ==
            flippedDeclarationNode.span.text;

    if (isDroppableDeclaration(mode, _originalDecl, _flippedDecl)) {
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
      setStartEnd(mode == RetensionMode.keepFlippedBidiSpecific
          ? flippedDecls
          : originalDecls);
    }
    else {
      didRetainDecls = true;
    }
  }

  /// Edits the rule sets in media directives.
  _editMediaDirective(TextEditTransaction trans, MediaDirective originalTopLevel, MediaDirective flippedTopLevel, RetensionMode mode, String dir,
      int iTopLevel) {
    var originalMDRuleSets = originalTopLevel.rulesets;
    var flippedMDRuleSets = flippedTopLevel.rulesets;
    for(int iRuleSet = 0; iRuleSet < originalMDRuleSets.length; iRuleSet++) {
      _editRuleSet(trans, originalMDRuleSets, flippedMDRuleSets, mode, dir, iRuleSet, _getEndOfRuleSet(trans, originalMDRuleSets[iRuleSet].span.end.offset) + 1);
    }
  }

  /// Edits the rulesets in host directive.
  _editHostDirective(TextEditTransaction trans, HostDirective originalTopLevel, HostDirective flippedTopLevel, RetensionMode mode, String dir,
      int iTopLevel) {
    var originalMDRuleSets = originalTopLevel.rulesets;
    var flippedMDRuleSets = flippedTopLevel.rulesets;
    for(int iRuleSet = 0; iRuleSet < originalMDRuleSets.length; iRuleSet++) {
      _editRuleSet(trans, originalMDRuleSets, flippedMDRuleSets, mode, dir, iRuleSet, _getEndOfRuleSet(trans, originalMDRuleSets[iRuleSet].span.end.offset) + 1);
    }
  }

  /// Removes declarations from the start and end points stored in [startPoints] and [endPoints].
      _removeDeclarations(TextEditTransaction trans) {
    for (int i = 0; i < startPoints.length; i++) {
      trans.edit(startPoints[i], endPoints[i], '');
    }
  }

  /// Removes direction independent directives from [orientationSpecific] and [flippedOrientationSpecific] transactions.
  _editDirectionIndependentDirectives(TextEditTransaction trans, var originalTopLevels, var flippedTopLevels, RetensionMode mode, int iTopLevel, int parentEnd) {
    if(mode != RetensionMode.keepBidiNeutral) {
      var ruleStartLocation =
          mode == RetensionMode.keepFlippedBidiSpecific
              ? flippedTopLevels[iTopLevel].span.start.offset - 1
              : originalTopLevels[iTopLevel].span.start.offset - 1;
      _removeRule(trans, originalTopLevels, flippedTopLevels, mode, iTopLevel, ruleStartLocation, parentEnd);
    }
  }

  /// Removes a rule from the transaction.
  _removeRule(TextEditTransaction trans, var originalTopLevels, var flippedTopLevels, RetensionMode mode, int iTopLevel, int ruleStartLocation, int parentEnd) {
    var end = iTopLevel < originalTopLevels.length - 1
        ? (mode == RetensionMode.keepFlippedBidiSpecific
        ? flippedTopLevels[iTopLevel + 1].span.start.offset - 1
        : originalTopLevels[iTopLevel + 1].span.start.offset - 1)
        : parentEnd;
    trans.edit(ruleStartLocation, end, '');
  }

  // Returns end location of ruleset in input transaction.
  int _getEndOfRuleSet(TextEditTransaction trans, int /*fromIndex*/end) {
    //                indexOF('}')
    // .foo { float: left /* becaue `foo: right;` would not work */; /* Haha { } */ }
    while (trans.file.getText(end, end + 1) != '\n') {
      end++;
    }
    return end;
  }

  /// Checks if a topLevel is direction independent.
  bool _isDirectionIndependent(var originalTopLevel) {
    if(_directionIndependentDirectives.contains(originalTopLevel.runtimeType))
      return true;
  }
}
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
library scissors.src.css_mirroring.bidi_css_generator;

import 'dart:async';

import 'package:csslib/parser.dart' show parse;
import 'package:csslib/visitor.dart' show RuleSet, TreeNode;

import 'package:source_maps/refactor.dart' show TextEditTransaction;
import 'package:source_span/source_span.dart' show SourceFile;

import 'buffered_transaction.dart';
import 'css_utils.dart' show isDirectionInsensitive, hasNestedRuleSets;
import 'directive_processors.dart' show editDirectiveWithNestedRuleSets;
import 'edit_configuration.dart';
import 'mirrored_entities.dart';
import 'rulesets_processor.dart' show editRuleSet;

/// Type of a function that does LTR/RTL mirroring of a css.
typedef Future<String> CssFlipper(String inputCss);

/// BidiCssGenerator generates a CSS which comprises of orientation neutral,
/// orientation specific and flipped orientation specific parts.
///
/// See BidirectionalCss.md for more details.
class BidiCssGenerator {
  final String _originalCss;
  final String _flippedCss;
  final String _sourceId;
  final Direction _nativeDirection;

  MirroredEntities<TreeNode> _topLevelEntities;

  BidiCssGenerator._(this._originalCss, this._flippedCss, this._sourceId,
      this._nativeDirection) {
    _topLevelEntities = new MirroredEntities(
        _originalCss,
        parse(_originalCss).topLevels,
        _flippedCss,
        parse(_flippedCss).topLevels);
  }

  static build(String originalCss, String cssSourceId,
      Direction nativeDirection, CssFlipper cssFlipper) async {
    return new BidiCssGenerator._(originalCss, await cssFlipper(originalCss),
        cssSourceId, nativeDirection);
  }

  /// Main function which returns the bidirectional CSS.
  String getOutputCss() {
    var parts = [
      _editCss(_originalCss, RetentionMode.keepBidiNeutral, _nativeDirection),
      _editCss(_originalCss, RetentionMode.keepOriginalBidiSpecific,
          _nativeDirection),
      _editCss(_flippedCss, RetentionMode.keepFlippedBidiSpecific,
          flipDirection(_nativeDirection))
    ];
    return parts.where((t) => t.trim().isNotEmpty).join('\n');
  }

  /// Takes transaction to edit, the retention mode which defines which part to
  /// retain and the direction of the output CSS.
  ///
  /// In case of rulesets it drops declarations in them and if all the declaration
  /// in it have to be removed, it removes the rule itself.
  ///
  /// In case of Directives, it edits rulesets in them and if all the rulesets have
  /// to be removed, it removes Directive Itself
  String _editCss(String css, RetentionMode mode, Direction targetDirection) {
    var trans =
        new TextEditTransaction(css, new SourceFile(css, url: _sourceId));
    var bufferedTrans = new BufferedTransaction(trans);

    _topLevelEntities.forEach((MirroredEntity<TreeNode> entity) {
      // Note: MirroredEntity guarantees type uniformity between original and
      // flipped.
      var original = entity.original.value;
      if (original is RuleSet) {
        editRuleSet(entity, mode, targetDirection, bufferedTrans);
      } else if (hasNestedRuleSets(original)) {
        editDirectiveWithNestedRuleSets(
            entity,
            entity.getChildren((d) => d.rulesets),
            mode,
            targetDirection,
            bufferedTrans);
      } else if (isDirectionInsensitive(original)) {
        if (mode != RetentionMode.keepBidiNeutral) {
          entity.remove(mode, bufferedTrans);
        }
      } else {
        throw new StateError('Node type not handled: ${original.runtimeType}');
      }
    });
    bufferedTrans.commit();

    return (trans.commit()..build('')).text;
  }
}

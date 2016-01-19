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
import 'css_utils.dart' show isDirectionInsensitive, hasNestedRuleSets, Direction, flipDirection;
import 'directive_processors.dart' show editFlippedDirectiveWithNestedRuleSets;
import 'mirrored_entities.dart';
import 'rulesets_processor.dart' show editFlippedRuleSet;

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
      _cleanupCss(_originalCss),
      _cleanupCss(_editFlippedCss(flipDirection(_nativeDirection)))
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
  String _editFlippedCss(Direction flippedDirection) {
    var trans = new TextEditTransaction(
        _flippedCss, new SourceFile(_flippedCss, url: _sourceId));
    var bufferedTrans = new BufferedTransaction(trans);

    _topLevelEntities.forEach((MirroredEntity<TreeNode> entity) {
      // Note: MirroredEntity guarantees type uniformity between original and
      // flipped.
      var flipped = entity.flipped;
      if (flipped.value is RuleSet) {
        editFlippedRuleSet(entity, flippedDirection, bufferedTrans);
      } else if (hasNestedRuleSets(flipped.value)) {
        editFlippedDirectiveWithNestedRuleSets(
            entity,
            entity.getChildren((d) => d.rulesets),
            flippedDirection,
            bufferedTrans);
      } else if (isDirectionInsensitive(flipped.value)) {
        flipped.remove(bufferedTrans);
      } else {
        throw new StateError('Node type not handled: ${flipped.runtimeType}');
      }
    });
    bufferedTrans.commit();

    return (trans.commit()..build('')).text;
  }
}

final noFlipCommentRx =
    new RegExp(r'/\*\*?\s*@noflip\s*\*/\s*', multiLine: true);

String _cleanupCss(String css) {
  return css.replaceAll(noFlipCommentRx, '');
}

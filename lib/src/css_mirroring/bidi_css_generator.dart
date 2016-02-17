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
import 'css_utils.dart'
    show isDirectionInsensitive, hasNestedRuleSets, Direction, flipDirection;
import 'directive_processors.dart' show editFlippedDirectiveWithNestedRuleSets;
import 'mirrored_entities.dart';
import 'rulesets_processor.dart' show editFlippedRuleSet;

/// Type of a function that does LTR/RTL mirroring of a css, CSSJanus-style.
typedef Future<String> CssFlipper(String inputCss);

/// Augment [originalCss] with flipped CSS rules, to support bidirectional
/// layouts. Uses [cssFlipper] to flip to whole css, then picks the parts that
/// were actually flipped and adds direction selectors to them (the selected
/// direction will be the opposite of [nativeDirection]).
///
/// Given `foo { color: blue; float: left }`, it generates:
///
///    foo { color: blue; float: left }
///    :host-context([dir="rtl"]) foo { float: right }
///
/// See BidirectionalCss.md for more details.
Future<String> bidirectionalizeCss(String originalCss, CssFlipper cssFlipper,
    [Direction nativeDirection = Direction.ltr]) async {
  var flippedDirection = flipDirection(nativeDirection);
  var flippedCss = await cssFlipper(originalCss);

  var topLevelEntities = new MirroredEntities(originalCss,
      parse(originalCss).topLevels, flippedCss, parse(flippedCss).topLevels);

  var trans =
      new TextEditTransaction(flippedCss, new SourceFile(flippedCss, url: ''));
  var bufferedTrans = new BufferedTransaction(trans);
  topLevelEntities.forEach((MirroredEntity<TreeNode> entity) {
    if (entity.isRuleSet) {
      editFlippedRuleSet(entity, flippedDirection, bufferedTrans);
    } else if (entity.hasNestedRuleSets) {
      editFlippedDirectiveWithNestedRuleSets(
          entity,
          entity.getChildren((d) => d.rulesets),
          flippedDirection,
          bufferedTrans);
    } else if (entity.isDirectionInsensitiveDirective) {
      entity.flipped.remove(bufferedTrans);
    } else {
      throw new StateError('Node type not handled: $entity');
    }
  });
  bufferedTrans.commit();

  var resultCss = _cleanupCss(originalCss);
  var taggedFlippedCss = _cleanupCss((trans.commit()..build('')).text);
  if (taggedFlippedCss.trim().isNotEmpty) resultCss += "\n" + taggedFlippedCss;
  return resultCss;
}

final _noFlipRx = new RegExp(r'/\*\*?\s*@noflip\s*\*/\s*', multiLine: true);

String _cleanupCss(String css) {
  return css.replaceAll(_noFlipRx, '');
}

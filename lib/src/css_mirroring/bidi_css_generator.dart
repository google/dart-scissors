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
import 'package:csslib/visitor.dart'
    show
        TreeNode,
        HostDirective,
        MediaDirective,
        StyletDirective,
        MixinRulesetDirective;

import 'package:source_maps/refactor.dart' show TextEditTransaction;
import 'package:source_span/source_span.dart' show SourceFile;

import 'buffered_transaction.dart';
import 'css_utils.dart' show Direction;
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
  var flippedCss = await cssFlipper(originalCss);

  var topLevelEntities = new MirroredEntities<TreeNode>(originalCss,
      parse(originalCss).topLevels, flippedCss, parse(flippedCss).topLevels);

  var flippedDirTrans = new TextEditTransaction(
      flippedCss, new SourceFile.fromString(flippedCss, url: ''));
  var bufferedFlippedDirTrans = new BufferedTransaction(flippedDirTrans);

  var nativeDirTrans = new TextEditTransaction(
      originalCss, new SourceFile.fromString(originalCss, url: ''));
  var bufferedNativeDirTrans = new BufferedTransaction(nativeDirTrans);

  var commonTrans = new TextEditTransaction(
      originalCss, new SourceFile.fromString(originalCss, url: ''));
  var bufferedCommonTrans = new BufferedTransaction(commonTrans);

  topLevelEntities.forEach((MirroredEntity<TreeNode> entity) {
    if (entity.isRuleSet) {
      editFlippedRuleSet(entity, nativeDirection, bufferedCommonTrans,
          bufferedNativeDirTrans, bufferedFlippedDirTrans);
    } else if (entity.hasNestedRuleSets) {
      editFlippedDirectiveWithNestedRuleSets(
          entity,
          entity.getChildren<TreeNode>(_getRules),
          nativeDirection,
          bufferedCommonTrans,
          bufferedNativeDirTrans,
          bufferedFlippedDirTrans);
    } else {
      entity.original.remove(bufferedNativeDirTrans);
      entity.flipped.remove(bufferedFlippedDirTrans);
    }
  });
  bufferedCommonTrans.commit();
  bufferedNativeDirTrans.commit();
  bufferedFlippedDirTrans.commit();

  var resultCss = _cleanupCss((commonTrans.commit()..build('')).text);
  var taggedOriginalDirCss =
      _cleanupCss((nativeDirTrans.commit()..build('')).text);
  var taggedFlippedDirCss =
      _cleanupCss((flippedDirTrans.commit()..build('')).text);
  if (taggedOriginalDirCss.trim().isNotEmpty)
    resultCss += "\n" + taggedOriginalDirCss;
  if (taggedFlippedDirCss.trim().isNotEmpty)
    resultCss += "\n" + taggedFlippedDirCss;
  return resultCss;
}

final _noFlipRx = new RegExp(r'/\*\*?\s*@noflip\s*\*/\s*', multiLine: true);

String _cleanupCss(String css) {
  return css.replaceAll(_noFlipRx, '');
}

List<TreeNode> _getRules(node) {
  if (node is HostDirective ||
      node is MediaDirective ||
      node is StyletDirective ||
      node is MixinRulesetDirective) {
    return node.rules;
  }
  return [];
}

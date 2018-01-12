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
library scissors.src.css_mirroring.bidi_css_generator.ruleset_processors;

import 'package:csslib/visitor.dart' show Declaration, RuleSet, Selector;
import 'package:quiver/check.dart';

import '../utils/enum_parser.dart';
import 'buffered_transaction.dart';
import 'css_utils.dart' show Direction, flipDirection;
import 'entity.dart';
import 'mirrored_entities.dart';

enum RemovalResult { none, some, all }

/// Returns all if the [RuleSet] was completely removed, none when the
/// rule was not modified at all and some otherwise.
RemovalResult editFlippedRuleSet(
    MirroredEntity mirroredRuleSet,
    Direction nativeDirection,
    BufferedTransaction commonTrans,
    BufferedTransaction nativeDirTrans,
    BufferedTransaction flippedDirTrans) {
  final commonSubTransaction = commonTrans.createSubTransaction();
  final nativeDirSubTransaction = nativeDirTrans.createSubTransaction();
  final flippedDirSubTransaction = flippedDirTrans.createSubTransaction();

  MirroredEntities<Declaration> mirroredDeclarations =
      mirroredRuleSet.getChildren((r) => new List<Declaration>.from(
          (r as RuleSet).declarationGroup.declarations));

  /// Iterate over Declarations in RuleSet and store start and end points of
  /// declarations to be removed.
  var commonCount = 0;
  var flippedCount = 0;
  mirroredDeclarations.forEach((MirroredEntity<Declaration> decl) {
    checkState(decl.flipped.value is Declaration,
        message: () => 'Expected a declaration, got $decl');

    if (decl.hasSameTextInBothVersions) {
      decl.original.remove(nativeDirSubTransaction);
      decl.flipped.remove(flippedDirSubTransaction);
      commonCount++;
    } else {
      decl.original.remove(commonSubTransaction);
      flippedCount++;
    }
  });

  assert(commonCount + flippedCount == mirroredDeclarations.length);

  RemovalResult removalResult = RemovalResult.some;
  if (flippedCount > 0) {
    if (commonCount == 0) {
      mirroredRuleSet.original.remove(commonTrans);
      removalResult = RemovalResult.all;
    } else {
      commonSubTransaction.commit();
    }

    /// Add direction attribute to RuleId for direction-specific RuleSet.
    var flippedDirection = flipDirection(nativeDirection);

    prependHostContextToEachSelector(mirroredRuleSet.original, nativeDirTrans,
        '[dir="${enumName(nativeDirection)}"]');
    prependHostContextToEachSelector(mirroredRuleSet.flipped, flippedDirTrans,
        '[dir="${enumName(flippedDirection)}"]');

    flippedDirSubTransaction.commit();
    nativeDirSubTransaction.commit();
  } else {
    removalResult = RemovalResult.none;
    mirroredRuleSet.flipped.remove(flippedDirTrans);
    mirroredRuleSet.original.remove(nativeDirTrans);
  }

  return removalResult;
}

/// Matches " :host" or ":host.foo" without matching ":host-context".
final _hostPrefixRx = new RegExp(r'^(\s*:host)(\(.*?\))?(?:$|[^\w-])');

void prependHostContextToEachSelector(
    Entity e, BufferedTransaction trans, String selector) {
  for (final Selector sel in _getSelectors(e.value as RuleSet)) {
    final start = sel.span.start.offset;
    int end = start;
    bool appendSpace = true;

    final text = sel.span.text;
    final match = _hostPrefixRx.matchAsPrefix(text);
    if (match != null) {
      appendSpace = false;
      // Replace :host, since :host-context will already apply to it.
      // Only a plain :host can be ditched; :host(...) must be kept.
      if (match.group(2) == null) end = start + match.group(1).length;
    }

    final prefix = ':host-context($selector)${appendSpace ? ' ' : ''}';
    trans.edit(start, end, prefix);
  }
}

List<Selector> _getSelectors(RuleSet r) => r.selectorGroup.selectors;

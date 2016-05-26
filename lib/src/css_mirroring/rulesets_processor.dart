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

import 'buffered_transaction.dart';
import 'css_utils.dart' show Direction;
import 'entity.dart';
import 'mirrored_entities.dart';
import '../utils/enum_parser.dart';
import 'css_utils.dart' show Direction, flipDirection;

/// Returns true if the [RuleSet] was completely removed, false otherwise.
bool editFlippedRuleSet(
    MirroredEntity<RuleSet> mirroredRuleSet,
    Direction nativeDirection,
    BufferedTransaction commonTrans,
    BufferedTransaction nativeDirTrans,
    BufferedTransaction flippedDirTrans) {
  final commonSubTransaction = commonTrans.createSubTransaction();
  final nativeDirSubTransaction = nativeDirTrans.createSubTransaction();
  final flippedDirSubTransaction = flippedDirTrans.createSubTransaction();

  MirroredEntities<Declaration> mirroredDeclarations =
      mirroredRuleSet.getChildren(
          (RuleSet r) => r.declarationGroup.declarations as List<Declaration>);

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

  bool removalResult = false;
  if (flippedCount > 0) {
    if (commonCount == 0) {
      mirroredRuleSet.original.remove(commonTrans);
      removalResult = true;
    } else {
      commonSubTransaction.commit();
    }

    /// Add direction attribute to RuleId for direction-specific RuleSet.
    var flippedDirection = flipDirection(nativeDirection);

    prependToEachSelector(mirroredRuleSet.original, nativeDirTrans,
        ':host-context([dir="${enumName(nativeDirection)}"]) ');
    prependToEachSelector(mirroredRuleSet.flipped, flippedDirTrans,
        ':host-context([dir="${enumName(flippedDirection)}"]) ');

    flippedDirSubTransaction.commit();
    nativeDirSubTransaction.commit();
  } else {
    mirroredRuleSet.flipped.remove(flippedDirTrans);
    mirroredRuleSet.original.remove(nativeDirTrans);
  }

  return removalResult;
}

void prependToEachSelector(
    Entity<RuleSet> e, BufferedTransaction trans, String s) {
  for (final Selector sel in _getSelectors(e.value)) {
    var start = sel.span.start.offset;
    trans.edit(start, start, s);
  }
}

List<Selector> _getSelectors(RuleSet r) => r.selectorGroup.selectors;

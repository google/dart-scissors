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
library scissors.src.css_mirroring.directive_processors;

import 'package:csslib/visitor.dart' show TreeNode;

import 'buffered_transaction.dart';
import 'css_utils.dart' show Direction;
import 'mirrored_entities.dart';
import 'rulesets_processor.dart' show editFlippedRuleSet, RemovalResult;

/// All removable declarations of ruleset are removed and if all declarations
/// in rulesets have to be removed, it removes ruleset itself.
/// Also if all rulesets have to be removed, it removes the directive.
editFlippedDirectiveWithNestedRuleSets(
    MirroredEntity directive,
    MirroredEntities<TreeNode> nestedRuleSets,
    Direction nativeDirection,
    BufferedTransaction commonTrans,
    BufferedTransaction nativeDirTrans,
    BufferedTransaction flippedDirTrans) {
  final commonSubTransaction = commonTrans.createSubTransaction();
  final nativeDirSubTransaction = nativeDirTrans.createSubTransaction();
  final flippedDirSubTransaction = flippedDirTrans.createSubTransaction();
  int removedAllCount = 0;
  int removedNoneCount = 0;
  nestedRuleSets.forEach((MirroredEntity<TreeNode> ruleSet) {
    var result = editFlippedRuleSet(
        ruleSet,
        nativeDirection,
        commonSubTransaction,
        nativeDirSubTransaction,
        flippedDirSubTransaction);
    if (result == RemovalResult.all) {
      removedAllCount++;
    } else if (result == RemovalResult.none) {
      removedNoneCount++;
    }
  });

  if (removedNoneCount == nestedRuleSets.length) {
    directive.original.remove(nativeDirTrans);
    directive.flipped.remove(flippedDirTrans);
  } else {
    if (removedAllCount == nestedRuleSets.length) {
      directive.original.remove(commonTrans);
    } else {
      commonSubTransaction.commit();
    }
    nativeDirSubTransaction.commit();
    flippedDirSubTransaction.commit();
  }
}

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

import 'package:csslib/visitor.dart' show Declaration, RuleSet;
import 'package:quiver/check.dart';

import 'buffered_transaction.dart';
import 'edit_configuration.dart';
import 'mirrored_entities.dart';
import '../utils/enum_parser.dart';

enum RemovalResult { removedSome, removedAll }

/// Returns true if the [RuleSet] was completely removed, false otherwise.
RemovalResult editRuleSet(MirroredEntity<RuleSet> mirroredRuleSet,
    RetentionMode mode, Direction targetDirection, BufferedTransaction trans) {
  final subTransaction = trans.createSubTransaction();

  MirroredEntities<Declaration> mirroredDeclarations = mirroredRuleSet
      .getChildren((RuleSet r) => r.declarationGroup.declarations);

  /// Iterate over Declarations in RuleSet and store start and end points of
  /// declarations to be removed.
  var removedCount = 0;
  mirroredDeclarations.forEach((MirroredEntity<Declaration> decl) {
    checkState(decl.original.value is Declaration,
        message: () => 'Expected a declaration, got $decl');

    bool isEqual =
        decl.original.value.span.text == decl.flipped.value.span.text;

    var shouldRemoveDecl =
        mode == RetentionMode.keepBidiNeutral ? !isEqual : isEqual;

    if (shouldRemoveDecl) {
      decl.remove(mode, subTransaction);
      removedCount++;
    }
  });

  var ruleSet = mirroredRuleSet.choose(mode);
  if (removedCount == mirroredDeclarations.length) {
    ruleSet.remove(trans);
    return RemovalResult.removedAll;
  } else {
    /// Add direction attribute to RuleId for direction-specific RuleSet.
    if (mode != RetentionMode.keepBidiNeutral) {
      var dir = enumName(targetDirection);
      ruleSet.prepend(trans, ':host-context([dir="$dir"]) ');
    }
    subTransaction.commit();
    return RemovalResult.removedSome;
  }
}

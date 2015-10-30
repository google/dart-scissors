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
library scissors.usage_collector;

import 'package:csslib/visitor.dart' show RuleSet;

import 'package:html/dom.dart' as dom;
import 'package:html/dom_parsing.dart' as dom_parsing;

import 'name_fragment.dart';
import 'ng_class_parser.dart';
import 'rule_set_index.dart';

/// Traverses DOM trees and collects [RuleSet]s that are matched.
/// This class errs on the side of caution, so it will collect any rules
/// where there is doubt about whether it is used.
class UsageCollector extends dom_parsing.TreeVisitor {
  final RuleSetIndex _index;

  /// Set of [RuleSet]s which were deemed to be used based on visited DOM nodes.
  final Set<RuleSet> rulesUsed = new Set<RuleSet>();

  /// Whether variable class names were detected during DOM traversal.
  /// Variable class names occur when using programmatic names in ng-class.
  bool didNotReliablyCollectAllClasses = false;

  UsageCollector(this._index);

  @override
  visitElement(dom.Element node) {
    var desc = new ElementDescription(
        node.localName, node.attributes["id"], node.attributes);

    for (Pattern pattern in parseClassPatterns(node.attributes["class"])) {
      if (pattern is String) {
        desc.classes.add(pattern);
      } else {
        desc.classFragments.add(pattern);
      }
    }
    _parseNgClassClassesAndClassFragments(node.attributes["ng-class"], desc);

    _index.matchingRulesForElement(desc).forEach(rulesUsed.add);

    super.visitElement(node);
  }

  void _parseNgClassClassesAndClassFragments(
      String ngClassAttribute, ElementDescription desc) {
    if (ngClassAttribute == null) return;
    final results = parseNgClassAttribute(ngClassAttribute);
    if (results == null) {
      didNotReliablyCollectAllClasses = true;
      return;
    }
    didNotReliablyCollectAllClasses =
        didNotReliablyCollectAllClasses || results.hasVariableClasses;
    desc.classes.addAll(results.classes);
  }
}

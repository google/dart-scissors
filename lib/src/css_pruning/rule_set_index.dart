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
library scissors.src.css_pruning.rule_set_index;

import 'package:csslib/parser.dart' show TokenKind;
import 'package:csslib/visitor.dart';

/// Simple naive index of [RuleSet] by CSS class, by element name, by id.
class RuleSetIndex {
  final Set<RuleSet> starRules = new Set<RuleSet>();
  final Map<String, Set<RuleSet>> rulesByClass = <String, Set<RuleSet>>{};
  final Map<String, Set<RuleSet>> rulesByElement = <String, Set<RuleSet>>{};
  final Map<String, Set<RuleSet>> rulesById = <String, Set<RuleSet>>{};

  _indexBy(name, RuleSet r, Map<String, Set<RuleSet>> index) =>
      index.putIfAbsent(name, () => new Set()).add(r);

  _indexByClass(name, RuleSet r) => _indexBy(name, r, rulesByClass);
  _indexByElement(name, RuleSet r) => _indexBy(name, r, rulesByElement);
  _indexById(name, RuleSet r) => _indexBy(name, r, rulesById);

  /// Return true iff managed to index [ruleSet] in a way that will allow
  /// matches through [matchingRulesForElement].
  bool add(RuleSet ruleSet) {
    bool addedToSomeIndex = false;
    for (final Selector sel in ruleSet.selectorGroup.selectors) {
      for (final seq in sel.simpleSelectorSequences) {
        final simpleSel = seq.simpleSelector;
        if (simpleSel is ClassSelector) {
          _indexByClass(simpleSel.name, ruleSet);
          addedToSomeIndex = true;
        } else if (simpleSel is IdSelector) {
          _indexById(simpleSel.name, ruleSet);
          addedToSomeIndex = true;
        } else if (simpleSel is PseudoClassSelector) {
          starRules.add(ruleSet);
        } else if (simpleSel is ElementSelector) {
          if (simpleSel.isWildcard) {
            starRules.add(ruleSet);
          } else {
            _indexByElement(simpleSel.name, ruleSet);
          }
          addedToSomeIndex = true;
        } else if (simpleSel is AttributeSelector) {
          // Do nothing here: we'll cross-match in [_isSelectorMatch].
        } else {
          // print('TODO: Handle simple selector $simpleSel: ${simpleSel.runtimeType}');
        }
      }
    }
    return addedToSomeIndex;
  }

  /// Pessimistically list all rules that match the provided [node] (and
  /// potentially also rules that don't actually match: that's what pessimism
  /// means).
  ///
  /// Returns a lazily-evaluated iterable.
  Iterable<RuleSet> matchingRulesForElement(ElementDescription node) =>
      _potentialMatches(node).where((r) => node.isMatchedByRuleSet(r));

  /// Get the rules that potentially match [node], either because they have a
  /// matching class name / matching class fragments, or a matching id, or a
  /// matching localName).
  Set<RuleSet> _potentialMatches(ElementDescription node) {
    final result = <RuleSet>[];

    addValues(String key, Map<String, Set<RuleSet>> map) {
      final values = map[key];
      if (values != null) result.addAll(values);
    }

    for (String c in node.classes) {
      addValues(c, rulesByClass);
    }
    for (RegExp rx in node.classFragments) {
      final classes = rulesByClass.keys.where(_matchedByRegExp(rx));
      for (String c in classes) addValues(c, rulesByClass);
    }

    if (node.id != null) addValues(node.id, rulesById);

    addValues(node.localName, rulesByElement);
    result.addAll(starRules);

    return result.toSet();
  }
}

typedef bool _RegExpPredicate(RegExp _);
_RegExpPredicate _matchesString(String s) =>
    (RegExp rx) => rx.matchAsPrefix(s) != null;

typedef bool _StringPredicate(String _);
_StringPredicate _matchedByRegExp(RegExp rx) =>
    (String s) => rx.matchAsPrefix(s) != null;

/// Simple description of a DOM element.
class ElementDescription {
  /// Element tag name without any namespace.
  final String localName;

  /// Id of the element, or null if it has no id.
  final String id;

  /// Classes of the element.
  final Set<String> classes = new Set();

  /// Angular2 computed attributes of the element (syntax `[attr.foo]="bar"`).
  final Set<String> computedAttributes = new Set();

  /// List of fragments of class names, when the class attribute contains
  /// mustache expressions. For instance, given `class="foo-{{...}}-bar", this
  /// will contain something like: `new RegExp(r'^foo-.*?-bar$')`.
  final List<RegExp> classFragments = [];

  /// Attributes of the element. Includes `class` and `id`, if present.
  /// Keys are [String]s or [dom.AttributeName]s as in [dom.Node.attributes].
  /// We only care about keys with no namespace, so we hit [attributes] with
  /// strings only (see limitations in `README.md`).
  final Map<dynamic, String> attributes;

  ElementDescription(this.localName, this.id, this.attributes);

  /// Whether the element is matched by [ruleSet].
  /// This implements some pessimistic best-attempt CSS matching.
  bool isMatchedByRuleSet(RuleSet ruleSet) =>
      ruleSet.selectorGroup.selectors.any(_isSelectorMatch);

  bool _isSelectorMatch(Selector sel) {
    // final seqNames = sel.simpleSelectorSequences
    //     .map((seq) => seq.simpleSelector.name)
    //     .toList();

    /// Ignore element descent: this will match elements regardless on whether
    /// their hierarchy matches the rule, but it's a simple and pessimistic
    /// approximation that is good enough for now.
    ///
    /// TODO(ochafik): Implement finer CSS semantics.
    final selectors = _skipElementDescent(sel.simpleSelectorSequences);
    for (final SimpleSelectorSequence selector in selectors) {
      // TODO(ochafik): Deal with operator.
      final SimpleSelector simpleSelector = selector.simpleSelector;
      final String name = simpleSelector.name;

      if (simpleSelector is PseudoClassSelector) {
        if (simpleSelector.name != 'host') {
          print('TODO: handle pseudo-selector ${simpleSelector.name}');
        }
        // Conservative pruning: preserve any ruleset with pseudo selectors.
        return true;
      } else if (simpleSelector is ClassSelector) {
        if (classes.contains(name) ||
            classFragments.any(_matchesString(name))) {
          continue;
        }
        return false;
      } else if (simpleSelector is IdSelector) {
        if (id != name) {
          return false;
        }
      } else if (simpleSelector is ElementSelector) {
        if (localName != name && !simpleSelector.isWildcard) {
          return false;
        }
      } else if (simpleSelector is AttributeSelector) {
        // TODO(ochafik): Handle other operators.
        if (simpleSelector.operatorKind == TokenKind.EQUALS) {
          if (!computedAttributes.contains(name) &&
              attributes[name] != simpleSelector.value) {
            return false;
          }
        } else {
          print(
              'TODO: handle operator ${simpleSelector.operatorKind}: $simpleSelector');
          return true;
        }
      } else {
        print('TODO: handle selector ${simpleSelector.runtimeType}');
        return true;
      }
    }
    return true;
  }

  List<SimpleSelectorSequence> _skipElementDescent(
      List<SimpleSelectorSequence> selectors) {
    var i = 0;
    final n = selectors.length;
    isDescLike(int kind) =>
        kind == TokenKind.COMBINATOR_DESCENDANT ||
        kind == TokenKind.COMBINATOR_GREATER;

    while (i < n - 1 && isDescLike(selectors[i + 1].combinator)) {
      i++;
    }
    return i == 0 ? selectors : selectors.skip(i).toList();
  }
}

part of scissors.src.css_mirroring.bidi_css_generator;

keepDirectionIndependentDirectivesInBidiNeutralTransaction(
    TextEditTransaction trans,
    EditConfiguration editConfig,
    FlippableEntities<TreeNode> topLevelsPair,
    int iTopLevel) {
  if (editConfig.mode != RetentionMode.keepBidiNeutral) {
    _removeRuleSet(trans,
        _getProcessedTopLevels(editConfig.mode, topLevelsPair), iTopLevel);
  }
}

/// All removable declarations of ruleset are removed and if all declarations
/// in rulesets have to be removed, it removes ruleset itself.
/// Also if all rulesets have to be removed, it removes the directive.
editRuleSetsInDirectionDependentDirectiveandRemoveEmptyDirective(
    TextEditTransaction trans,
    EditConfiguration editConfig,
    FlippableEntities topLevelsPair,
    int iTopLevel) {
  final _originalRuleSets = topLevelsPair.originals[iTopLevel].rulesets;
  final _flippedRuleSets = topLevelsPair.flippeds[iTopLevel].rulesets;
  FlippableEntities<TreeNode> ruleSetsPair =
      new FlippableEntities<TreeNode>(_originalRuleSets, _flippedRuleSets);
  final _usedDirective =
      _getProcessedTopLevels(editConfig.mode, topLevelsPair)[iTopLevel];
  var _removableRuleSets;

  ruleSetsPair.forEach((FlippableEntity<Declaration> declEntity) {
    _removableRuleSets = removeDeclarationsAndPrependDirectionToRuleSet(
        trans,
        editConfig,
        ruleSetsPair,
        declEntity.index,
        _usedDirective.span.end.offset);
  });

  if (_removableRuleSets.getRemovalStartEndLocations().length ==
      _originalRuleSets.length) {
    // All rules are to be removed.
    _removeDirective(trans, _usedDirective);
  } else {
    _removableRuleSets.commit();
  }
}

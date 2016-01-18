part of scissors.src.css_mirroring.bidi_css_generator;

PendingRemovals removeDeclarationsAndPrependDirectionToRuleSet(
    TextEditTransaction trans,
    EditConfiguration editConfig,
    FlippableEntities<TreeNode> topLevelsPair,
    int iTopLevel,
    int parentEnd) {
  final removableRuleSets = new PendingRemovals(trans);
  final removableDeclarations = new PendingRemovals(trans);
  final List<TreeNode> processedTopLevelsBasedOnMode =
      _getProcessedTopLevels(editConfig.mode, topLevelsPair);

  _removeDeclarations(
      editConfig, topLevelsPair, iTopLevel, removableDeclarations);

  if (_isRuleRemovable(
      removableDeclarations, topLevelsPair.originals[iTopLevel])) {
    removableRuleSets.remove(
        _getNodeStart(processedTopLevelsBasedOnMode[iTopLevel]),
        _getRuleSetEnd(processedTopLevelsBasedOnMode, iTopLevel, parentEnd));
  } else {
    removableDeclarations.commit();

    /// Add direction attribute to RuleId for direction-specific RuleSet.
    if (editConfig.mode != RetentionMode.keepBidiNeutral) {
      _prependDirectionToRuleSet(
          trans, editConfig, processedTopLevelsBasedOnMode[iTopLevel]);
    }
  }
  return removableRuleSets;
}

/// Stores start and end locations of removable declarations in a ruleset
/// based upon the retention mode.
void _removeDeclarations(
    EditConfiguration editConfig,
    FlippableEntities<TreeNode> topLevelsPair,
    int iTopLevel,
    PendingRemovals removals) {
  var originalDecls = getDecls(topLevelsPair.originals[iTopLevel]);
  var flippedDecls = getDecls(topLevelsPair.flippeds[iTopLevel]);
  FlippableEntities<Declaration> declsPair =
      new FlippableEntities<Declaration>(originalDecls, flippedDecls);
  var decls = (editConfig.mode == RetentionMode.keepFlippedBidiSpecific)
      ? flippedDecls
      : originalDecls;

  /// Iterate over Declarations in RuleSet and store start and end points of
  /// declarations to be removed.
  declsPair.forEach((FlippableEntity<TreeNode> declEntity) {
    if (_areDeclarations(declEntity.original, declEntity.flipped)) {
      if (_shouldRemoveDecl(
          editConfig.mode, declEntity.original, declEntity.flipped)) {
        removals.remove(decls[declEntity.index].span.start.offset,
            getDeclarationEnd(removals.source, decls, declEntity.index));
      }
    } else {
      checkState(
          declEntity.original.runtimeType == declEntity.flipped.runtimeType);
    }
  });
}

/// Removes declarations from ruleset depending upon the rentention mode.
/// Also removes empty rules.
removeDeclarationsAndDeleteEmptyRuleSets(
    TextEditTransaction trans,
    EditConfiguration editConfig,
    FlippableEntities<TreeNode> topLevelsPair,
    int iTopLevel) {
  removeDeclarationsAndPrependDirectionToRuleSet(
      trans, editConfig, topLevelsPair, iTopLevel, trans.file.length).commit();
}

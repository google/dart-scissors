part of scissors.src.css_mirroring.bidi_css_generator;

/// Makes transaction from input string.
TextEditTransaction _makeTransaction(String inputCss, String url) =>
    new TextEditTransaction(inputCss, new SourceFile(inputCss, url: url));

///  Checks if a topLevel tree node is direction independent.
bool _areDirIndependentDirectives(FlippableEntity<TreeNode> tnode) =>
    (tnode.original.runtimeType == tnode.flipped.runtimeType &&
        (tnode.original is CharsetDirective ||
            tnode.original is FontFaceDirective ||
            tnode.original is ImportDirective ||
            tnode.original is NamespaceDirective));

bool _areRuleSets(FlippableEntity<TreeNode> tnode) =>
    (tnode.original is RuleSet && tnode.flipped is RuleSet);

bool _areDirDependentDirectives(FlippableEntity<TreeNode> tnode) =>
    (tnode.original.runtimeType == tnode.flipped.runtimeType &&
        (tnode.original is MediaDirective || tnode.flipped is HostDirective));

bool _areDeclarations(TreeNode a, TreeNode b) =>
    a is Declaration && b is Declaration;

bool _areDeclarationsTextEqual(Declaration a, Declaration b) =>
    a.span.text == b.span.text;

/// A rule can be removed if all the declarations in the rule can be removed.
bool _isRuleRemovable(PendingRemovals removals, RuleSet rule) =>
    removals.getRemovalStartEndLocations().length ==
        rule.declarationGroup.declarations.length;

/// Checks if the declaration has to be removed based on the the Retention mode.
bool _shouldRemoveDecl(
    RetentionMode mode, Declaration original, Declaration flipped) {
  final bool isEqual = _areDeclarationsTextEqual(original, flipped);
  return mode == RetentionMode.keepBidiNeutral ? !isEqual : isEqual;
}

int _getNodeStart(TreeNode node) {
  if (node is RuleSet) return node.span.start.offset;
// In case of Directives since the node span start does not include '@'
// so additional -1 is required.
  return node.span.start.offset - 1;
}

/// If it is the last rule of ruleset delete rule till the end of parent which is
/// document end in case of a toplevel ruleset and is directive end if ruleset is
/// part of a toplevel directive like @media directive.
int _getRuleSetEnd(List<RuleSet> ruleSets, int ruleSetIndex, int parentEnd) {
  final int end = ruleSetIndex < ruleSets.length - 1
      ? _getNodeStart(ruleSets[ruleSetIndex + 1])
      : parentEnd;
  return end;
}

int getDeclarationEnd(String source, List<Declaration> decls, int iDecl) {
  if (iDecl < decls.length - 1) {
    return decls[iDecl + 1].span.start.offset;
  }

  final int fileLength = source.length;
  int fromIndex = decls[iDecl].span.end.offset;
  try {
    while (fromIndex + 1 < fileLength) {
      if (source.substring(fromIndex, fromIndex + 2) == '/*') {
        while (source.substring(fromIndex, fromIndex + 2) != '*/') {
          fromIndex++;
        }
      } else if (source[fromIndex] == '}') {
        return fromIndex;
      }
      fromIndex++;
    }
  } on RangeError catch (_) {
    throw new ArgumentError('Invalid CSS');
  }
  // Case when it doesnot find the end of declaration till file end.
  if (source[fromIndex] == '}') {
    return fromIndex;
  }
  throw new ArgumentError('Declaration end not found');
}

List<TreeNode> _getProcessedTopLevels(
        RetentionMode mode, FlippableEntities topLevelsPair) =>
    (mode == RetentionMode.keepFlippedBidiSpecific)
        ? topLevelsPair.flippeds
        : topLevelsPair.originals;

void _removeDirective(TextEditTransaction trans, TreeNode topLevel) =>
    trans.edit(_getNodeStart(topLevel), topLevel.span.end.offset, '');

void _prependDirectionToRuleSet(
    TextEditTransaction trans, EditConfiguration editConfig, RuleSet ruleSet) {
  trans.edit(ruleSet.span.start.offset, ruleSet.span.start.offset,
      ':host-context([dir="${enumName(editConfig.targetDirection)}"]) ');
}

/// Removes a rule from the transaction.
void _removeRuleSet(
    TextEditTransaction trans, List<RuleSet> rulesets, int ruleSetIndex) {
  trans.edit(_getNodeStart(rulesets[ruleSetIndex]),
      _getRuleSetEnd(rulesets, ruleSetIndex, trans.file.length), '');
}

List<Declaration> getDecls(RuleSet a) => a.declarationGroup.declarations;

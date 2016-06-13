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
library scissors.src.css_pruning.css_pruning;

import 'dart:async';

import 'package:barback/barback.dart';
import 'package:csslib/parser.dart' as css_parser;
import 'package:csslib/visitor.dart'
    show CssPrinter, RuleSet, StyleSheet, TreeNode;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:quiver/check.dart';
import 'package:source_maps/refactor.dart';
import 'package:source_span/source_span.dart';

import '../utils/hacks.dart' as hacks;

import 'rule_set_index.dart';
import 'template_extractor.dart' show extractTemplates;
import 'usage_collector.dart';
import 'transformer.dart' show CssPruningSettings;

Future<String> findHtmlTemplate(Transform transform, AssetId cssAssetId) async {
  try {
    var dartAssetId = _getCssCompanionId(cssAssetId, ".dart");
    var dartAsset = await transform.getInput(dartAssetId);
    var templates = await extractTemplates(transform, dartAsset, cssAssetId);
    if (templates.isNotEmpty) return templates.join('\n');
  } on AssetNotFoundException catch (_) {
    // Do nothing.
  }
  var htmlAssetId = _getCssCompanionId(cssAssetId, ".html");
  var htmlAsset = await transform.getInput(htmlAssetId);
  return htmlAsset.readAsString();
}

AssetId _getCssCompanionId(AssetId cssId, String companionExtension) {
  final path = cssId.path;
  checkArgument(path.endsWith(".css"));
  if (path.endsWith('.scss.css') || path.endsWith('.sass.css')) {
    return new AssetId(
        cssId.package,
        path.substring(0, path.length - '.scss.css'.length) +
            companionExtension);
  } else {
    return cssId.changeExtension(companionExtension);
  }
}

/// Edits [transaction] to drop any CSS rule in [topLevels] that we're sure
/// is not referred to by any DOM node in [htmlTrees].
dropUnusedCssRules(
    Transform transform,
    TextEditTransaction transaction,
    CssPruningSettings settings,
    SourceFile cssSourceFile,
    String htmlTemplate) {
  hacks.useCssLib();

  final StyleSheet cssTree =
      new css_parser.Parser(cssSourceFile, transaction.original).parse();
  final List<dom.Node> htmlTrees =
      _skipSyntheticNodes(html_parser.parse(htmlTemplate), htmlTemplate);
  List<TreeNode> topLevels = cssTree.topLevels;

  final Set<TreeNode> topLevelsToPreserve =
      _findTopLevelsToPreserve(topLevels, htmlTrees);

  final Map<TreeNode, int> topLevelsToDropWithIndex = {};
  for (int i = 0; i < topLevels.length; i++) {
    final node = topLevels[i];
    if (!topLevelsToPreserve.contains(node)) {
      topLevelsToDropWithIndex[node] = i;
    }
  }

  final fileLength = transaction.file.length;
  topLevelsToDropWithIndex.forEach((TreeNode topLevel, int i) {
    if (settings.verbose.value) {
      transform.logger.info("Dropping unused CSS rule: "
          "${_printCss(new StyleSheet([topLevel], null))}");
    }
    final start = topLevel.span.start.offset;
    final end = i == topLevels.length - 1
        ? fileLength
        : topLevels[i + 1].span.start.offset;
    transaction.edit(start, end, '');
  });
}

Set<TreeNode> _findTopLevelsToPreserve(
    List<TreeNode> topLevels, List<dom.Node> htmlTrees) {
  final Set<TreeNode> topLevelsToPreserve = new Set();

  final RuleSetIndex index = new RuleSetIndex();
  for (final node in topLevels) {
    if (node is! RuleSet || !index.add(node)) {
      // Preserve all top-level declarations that aren't RuleSet, or that we
      // failed to index (because they're not supported yet).
      topLevelsToPreserve.add(node);
    }
  }

  final usageCollector = new UsageCollector(index);
  htmlTrees.forEach(usageCollector.visit);
  if (usageCollector.didNotReliablyCollectAllClasses) {
    // TODO(ochafik): make this a proper pub warning / error, with details.
    throw new UnsupportedError("Cannot reliably prune this CSS file, "
        "maybe because of some unsupported ng-class syntax");
  }
  topLevelsToPreserve.addAll(usageCollector.rulesUsed);
  return topLevelsToPreserve;
}

String _printCss(tree) =>
    (new CssPrinter()..visitTree(tree, pretty: true)).toString();

/// The [doc] will always contain <html> and <body> tags, even if they weren't
/// in the original source. Skip those synthetic nodes to avoid spurious
/// matching of CSS rules on html and body elements.
List<dom.Node> _skipSyntheticNodes(dom.Document doc, String source) {
  // TODO(ochafik): Cleanup the source.contains hack by fixing the html parser.
  //     (does not set source spans, so we don't really know when a node is
  //     synthetic :-S)

  if (doc.children.length == 1) {
    final html = doc.firstChild;
    if (html is dom.Element && html.localName == 'html') {
      if (html.sourceSpan != null || source.contains("<html")) return [html];
      if (html.children.length == 2 &&
          html.children[0].localName == 'head' &&
          html.children[1].localName == 'body') {
        final body = html.children.last;
        if (body.sourceSpan != null || source.contains("<body")) return [body];
        return body.children;
      }
    }
  }
  return doc.children;
}

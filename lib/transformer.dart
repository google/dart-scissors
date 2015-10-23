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
library scissors.transformer;

import 'dart:async';
import 'dart:io';

import 'package:barback/barback.dart';
import 'package:code_transformers/resolver.dart' show Resolvers;
import 'package:code_transformers/src/dart_sdk.dart' show dartSdkDirectory;
import 'package:csslib/parser.dart' as css_parser;
import 'package:csslib/visitor.dart'
    show CssPrinter, RuleSet, StyleSheet, TreeNode;
import 'package:csslib/src/messages.dart' show messages, Messages;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:quiver/check.dart';
import 'package:source_maps/refactor.dart';
import 'package:source_maps/printer.dart';
import 'package:source_span/source_span.dart';

import 'src/rule_set_index.dart';
import 'src/sassc.dart' show runSassC;
import 'src/template_extractor.dart' show extractTemplates;
import 'src/usage_collector.dart';

/// sCiSSors is an Angular tree-shaker for CSS files.
/// It drops CSS rule sets that are not referenced from Angular templates.
class ScissorsTransformer extends Transformer {
  final bool _isDebug;
  final String _sasscPath;
  final List<String> _sasscArgs;
  Resolvers resolvers;

  ScissorsTransformer.asPlugin(BarbackSettings settings)
      : this._isDebug = settings.mode == BarbackMode.DEBUG,
        this._sasscPath = settings.configuration['sassc'] ?? 'sassc',
        this._sasscArgs = settings.configuration['sasscArgs'] ?? const<String>[] {
    resolvers = new Resolvers(
        checkNotNull(dartSdkDirectory, message: "dartSdkDirectory not found!"));
  }

  @override
  String get allowedExtensions => ".css .scss .sass";

  static AssetId _getCssCompanionId(AssetId cssId, String companionExtension) {
    final path = cssId.path;
    checkArgument(path.endsWith(".css"));
    if (path.endsWith('.scss.css') || path.endsWith('.sass.css')) {
      return new AssetId(
          cssId.package,
          path.substring(0, path.length - '.scss.css'.length)
              + companionExtension);
    } else {
      return cssId.changeExtension(companionExtension);
    }
  }

  Future<String> _findHtmlTemplate(
      Transform transform, AssetId cssAssetId) async {
    try {
      var dartAssetId = _getCssCompanionId(cssAssetId, ".dart");
      var dartAsset = await transform.getInput(dartAssetId);
      var templates = await extractTemplates(transform, dartAsset, cssAssetId);
      if (templates.isNotEmpty) return templates.join('\n');
    } catch (e, s) {
      if (e is! AssetNotFoundException) print('$e (${e.runtimeType})\n$s');
    }
    var htmlAssetId = _getCssCompanionId(cssAssetId, ".html");
    var htmlAsset = await transform.getInput(htmlAssetId);
    return htmlAsset.readAsString();
  }

  Future apply(Transform transform) async {
    var primaryId = transform.primaryInput.id;
    var ext = primaryId.extension;
    switch (ext) {
      case '.scss':
      case '.sass':
        try {
          await transform.getInput(primaryId.changeExtension('$ext.css'));
        } catch (e, s) {
          if (e is! AssetNotFoundException) {
            throw new StateError('$e (${e.runtimeType})\n$s');
          }
          return transformSassAsset(transform);
        }
        break;
      case '.css':
        return transformCssAsset(transform, transform.primaryInput);
      default:
        throw new StateError('Unexpected input file type: $primaryId');
    }
  }

  Future transformSassAsset(Transform transform) async {
    var sassAsset = transform.primaryInput;
    transform.logger.info("Running ${_sasscPath} on ${sassAsset.id}");
    var result = await runSassC(
      sassAsset, isDebug: _isDebug, sasscPath: _sasscPath, sasscArgs: _sasscArgs);

    result.messages.forEach((m) => m.log(transform));

    if (result.success) {
      transform.consumePrimary();
      // TODO(ochafik): Use a transformer group instead of chaining the transforms explicitly like this.
      return transformCssAsset(transform, result.css, result.map);
    }
  }

  Future transformCssAsset(Transform transform, Asset cssAsset, [Asset mapAsset]) async {
    //var cssAsset = transform.primaryInput;
    var cssAssetId = cssAsset.id;

    String htmlTemplate;
    try {
      htmlTemplate = await _findHtmlTemplate(transform, cssAssetId);
    } catch (_) {
      // No HTML template found: leave the CSS alone!
      transform.addOutput(cssAsset);
      if (mapAsset != null) transform.addOutput(mapAsset);
      return;
    }

    try {
      final String css = await cssAsset.readAsString();
      final SourceFile cssSourceFile = new SourceFile(css, url: "$cssAssetId");

      // TODO(ochafik): This ugly wart is because of csslib's global messages.
      // See //third_party/dart/csslib/lib/src/messages.dart.
      messages = new Messages();
      final StyleSheet cssTree =
          new css_parser.Parser(cssSourceFile, css).parse();
      final List<dom.Node> htmlTrees =
          _skipSyntheticNodes(html_parser.parse(htmlTemplate), htmlTemplate);

      TextEditTransaction transaction =
          new TextEditTransaction(css, cssSourceFile);
      _dropUnusedCssRules(transform, transaction, cssTree.topLevels, htmlTrees);

      if (transaction.hasEdits) {
        final NestedPrinter printer = transaction.commit()
          ..build(cssAssetId.path);
        final String processedCss = printer.text;

        transform.logger.info("Size($cssAssetId): "
            "before = ${css.length}, after = ${processedCss.length}");
        transform.addOutput(new Asset.fromString(cssAssetId, processedCss));
      }
    } catch (e, s) {
      if (_isDebug) print("$e\n$s");
      transform.logger.warning("Failed to prune $cssAssetId: $e");
    }
  }

  /// Edits [transaction] to drop any CSS rule in [topLevels] that we're sure
  /// is not referred to by any DOM node in [htmlTrees].
  _dropUnusedCssRules(Transform transform, TextEditTransaction transaction,
      List<TreeNode> topLevels, List<dom.Node> htmlTrees) {
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
      transform.logger.info("Dropping unused CSS rule: "
          "${_printCss(new StyleSheet([topLevel], null))}");
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
}

/// The [doc] will always contain <html> and <body> tags, even if they weren't
/// in the original source. Skip those synthetic nodes to avoid spurious
/// matching of CSS rules on html and body elements.
List<dom.Node> _skipSyntheticNodes(dom.Document doc, String source) {
  // TODO(ochafik): Cleanup the source.contains hack by fixing the html parser.
  //     (does not set source spans, so we don't really know when a node is
  //     synthetic :-S)
  final html = doc.firstChild;
  if (html.sourceSpan != null || source.contains("<html")) return [html];
  final body = html.children.last;
  if (body.sourceSpan != null || source.contains("<body")) return [body];
  return body.children;
}

Future<ProcessResult> runProcessWithPipedInput(String executable, List<String> args, {String pipedInput}) async {
  var process = await Process.start(executable, args);

  Future<String> foldStream(Stream<List<int>> stream) async {
    var buffer = new StringBuffer();
    await for (var data in stream.transform(SYSTEM_ENCODING.decoder)) {
      buffer.write(data);
    }
    return buffer.toString();
  }

  var stdout = foldStream(process.stdout);
  var stderr = foldStream(process.stderr);

  process.stdin..writeln(pipedInput)..close();

  var result = await Future.wait([process.exitCode, stdout, stderr]);
  return new ProcessResult(pid, result[0], result[1], result[2]);
}

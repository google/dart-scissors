// Copyright 2016 Google Inc. All Rights Reserved.
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
library scissors.src.checker.transformer;

import 'dart:async';

import 'package:analyzer/src/generated/engine.dart' show AnalysisOptionsImpl;
import 'package:barback/barback.dart'
    show
        Asset,
        AssetId,
        AssetNotFoundException,
        BarbackSettings,
        LogLevel,
        Transform,
        Transformer;
import 'package:code_transformers/resolver.dart'
    show dartSdkDirectory, Resolver, Resolvers, ResolverTransformer;
import 'package:path/path.dart' as path;

import 'unawaited_futures_visitor.dart'
    show UnawaitedFuturesVisitor, ignoreUnawaitedFutureComment;
import '../utils/result.dart';
import '../utils/settings_base.dart';
import '../utils/source_spans.dart' show sourceSpanForNode;

part 'settings.dart';

const String unawaitedFutureMessage =
    'Unawaited future (ignore with `$ignoreUnawaitedFutureComment`)';

/// Static checker that attempts to spot errors such as:
/// - unawaited futures
///
class CheckerTransformer extends Transformer with ResolverTransformer {
  final CheckerSettings _settings;

  CheckerTransformer.asPlugin(BarbackSettings settings)
      : _settings = new CheckerSettings(settings) {
    resolvers = new Resolvers(dartSdkDirectory,
        options: new AnalysisOptionsImpl()
          ..strongMode = _settings.strong.value);
  }

  @override
  Future<bool> isPrimary(AssetId id) =>
      new Future.value(id.extension == ".dart");

  @override
  Future<bool> shouldApplyResolver(Asset asset) => new Future.value(true);

  @override
  applyResolver(Transform transform, Resolver resolver) async {
    final primaryInput = transform.primaryInput;

    if (_settings.unawaitedFuturesLevel.value == null) return;

    for (var libElement in resolver.libraries) {
      if (resolver.getSourceAssetId(libElement) == primaryInput.id) {
        for (var unitElement in libElement.units) {
          var id = primaryInput.id;
          if (unitElement.uri != null) {
            id = new AssetId(
                id.package, path.join(path.dirname(id.path), unitElement.uri));
          }
          Asset asset;
          try {
            asset = await transform.getInput(id);
          } on AssetNotFoundException catch (_) {
            transform.logger.warning('Asset not found: $id');
          }

          var unawaitedFuturesVisitor = new UnawaitedFuturesVisitor();
          var unit = unitElement.unit;
          unit.accept(unawaitedFuturesVisitor);

          for (var node in unawaitedFuturesVisitor.unawaitedFutures) {
            new TransformMessage(
                    _settings.unawaitedFuturesLevel.value,
                    unawaitedFutureMessage,
                    id,
                    await sourceSpanForNode(node, asset, unit.lineInfo))
                .log(transform.logger);
          }
        }
      }
    }
  }
}

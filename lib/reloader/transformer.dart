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
library scissors.src.parts_check.transformer;

import 'package:barback/barback.dart';

import 'dart:math';
import 'dart:async';

const _extension = '.timestamp';
const _timestampAggregate = 'web/timestamp';

/// Auto-reload transformer:
/// - in release (default for pub build), removes mentions / usages of the
///   reloader library without messing sourcemaps up.
/// - in debug (default for pub serve), eagerly timestamps all assets and lazily
///   aggregates the most recent timestamps, so that the reloader library can
///   query `/timestamp` and decide whether to reload the page or not.
class AutoReloadTransformerGroup extends TransformerGroup {
  AutoReloadTransformerGroup.asPlugin(BarbackSettings settings)
      : super(settings.mode == BarbackMode.RELEASE
            ? [
                [new _ReloaderRemovalTransformer()]
              ]
            : [
                [new _TimestamperTransformer()],
                [new _TimestampAggregateTransformer()]
              ]) {
    if (settings.configuration.isNotEmpty) {
      throw new ArgumentError(
          "Unsupported settings: ${settings.configuration}");
    }
  }
}

class _TimestamperTransformer extends Transformer
    implements DeclaringTransformer {
  @override bool isPrimary(AssetId id) => id.extension != _extension;

  @override
  apply(Transform transform) async {
    var id = transform.primaryInput.id;
    transform.logger.fine('Timestampping $id');
    transform.addOutput(
        new Asset.fromString(id.addExtension(_extension), _timestamp()));
  }

  _timestamp() => new DateTime.now().millisecondsSinceEpoch.toString();

  @override
  declareOutputs(DeclaringTransform transform) {
    var id = transform.primaryId;
    if (id.extension != _extension) {
      transform.declareOutput(id.addExtension(_extension));
    }
  }
}

class _TimestampAggregateTransformer extends AggregateTransformer
    implements LazyAggregateTransformer {
  @override
  classifyPrimary(AssetId id) =>
      id.extension == _extension ? 'timestamps' : null;

  @override
  apply(AggregateTransform transform) async {
    var maxTimestamp = 0;

    var futures = [];
    await for (var input in transform.primaryInputs) {
      futures.add((() async {
        var timestamp = int.parse(await input.readAsString());
        maxTimestamp = max(timestamp, maxTimestamp);
      })());
    }
    await Future.wait(futures);

    transform.logger.info('maxTimestamp = $maxTimestamp');
    transform.addOutput(new Asset.fromString(
        new AssetId(transform.package, _timestampAggregate),
        maxTimestamp.toString()));
  }

  @override
  declareOutputs(DeclaringAggregateTransform transform) {
    transform
        .declareOutput(new AssetId(transform.package, _timestampAggregate));
  }
}

String _spaces(int count) {
  var b = new StringBuffer();
  for (int i = 0; i < count; i++) b.write(' ');
  return b.toString();
}

/// Replaces import and usage of the reloader runtime support script by spaces.
/// This means we don't mess up with the sourcemaps.
class _ReloaderRemovalTransformer extends Transformer
    implements LazyTransformer {
  final RegExp _importRx = new RegExp(
      r'''\bimport\s*['"]package:scissors/reloader/reloader.dart['"]\s*(?:as\s*(\w+)\s*)?;''',
      multiLine: true);
  final RegExp _setupRx = new RegExp(
      r'''\b(?:(\w+)\s*\.\s*)?setupReloader\s*\([^;]*?\)\s*;''',
      multiLine: true);

  @override final String allowedExtensions = ".dart";

  @override
  declareOutputs(DeclaringTransform transform) {
    transform.declareOutput(transform.primaryId);
  }

  @override
  apply(Transform transform) async {
    var asset = transform.primaryInput;
    var src = await asset.readAsString();
    var aliases = <String>[];
    src = src.replaceAllMapped(_importRx, (Match m) {
      var s = m.group(0);
      aliases.add(m.group(1));
      return _spaces(s.length);
    });
    if (aliases.isNotEmpty) {
      transform.logger.info('Removing reference to reloader');
      src = src.replaceAllMapped(_setupRx, (Match m) {
        var prefix = m.group(1);
        var s = m.group(0);
        if (aliases.contains(prefix)) {
          return _spaces(s.length);
        } else {
          return s;
        }
      });
      transform.addOutput(new Asset.fromString(asset.id, src));
    }
  }

  @override String toString() => 'ReloaderRemoval';
}

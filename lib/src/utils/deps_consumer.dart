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
library scissors.src.utils.deps_consumer;

import 'dart:async';
import 'dart:io';

import 'package:barback/barback.dart' show TransformLogger, Asset, AssetId;
import 'package:path/path.dart';

import 'path_resolver.dart';

final RegExp _importRx = new RegExp(r'''^\s*@import ['"]([^'"]+)['"]''');
final RegExp _commentsRx =
    new RegExp(r'''//.*?\n|/\*.*?\*/''', multiLine: true);

/// Eagerly consume transitive sass imports.
///
/// Calling [Transform.getInput] has the effect of telling barback about the
/// file dependency tree: when pub serve is run with --force-poll, any change
/// on any of the transitive dependencies will result in a re-compilation
/// of the SASS file(s).
Future<Set<AssetId>> consumeTransitiveSassDeps(
    Future<Asset> inputGetter(AssetId id),
    TransformLogger logger,
    Asset asset,
    List<Directory> sassIncludes,
    [Set<AssetId> visitedIds]) async {
  visitedIds ??= new Set<AssetId>();
  if (visitedIds.add(asset.id)) {
    // TODO(ochafik): Handle .sass files?
    var sass = await asset.readAsString();
    var futures = <Future>[];
    for (var match in _importRx.allMatches(sass.replaceAll(_commentsRx, ''))) {
      var url = match.group(1);
      var urls = <String>[];
      if (url.endsWith('.scss')) {
        urls.add(url);
      } else {
        // Expand sass partial: foo/bar -> foo/_bar.scss
        var split = url.split('/');
        split[split.length - 1] = '_${split.last}.scss';
        urls.add(split.join('/'));
        urls.add(url + '.scss');
      }

      futures.add((() async {
        try {
          var files = <String>[]..addAll(urls);
          for (var sassInclude in sassIncludes) {
            files.addAll(urls.map((u) => relative(join(sassInclude.path, u))));
          }
          var importedAsset =
              await pathResolver.resolveAsset(inputGetter, files, asset.id);
          await consumeTransitiveSassDeps(
              inputGetter, logger, importedAsset, sassIncludes, visitedIds);
        } catch (e, s) {
          logger.warning(
              "Failed to resolve import of '$url' from ${asset.id}: $e\n$s");
        }
      })());
    }
    await Future.wait(futures);
  }
  return visitedIds;
}

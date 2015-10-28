import 'package:barback/barback.dart' show Transform, Asset, AssetId;
import 'dart:async';
import 'package:scissors/src/path_resolver.dart';

final RegExp _importRx = new RegExp('''@import ['"](.*)['"]''');

/// Eagerly consume transitive sass imports.
///
/// Calling [Transform.getInput] has the effect of telling barback about the
/// file dependency tree: when pub serve is run with --force-poll, any change
/// on any of the transitive dependencies will result in a re-compilation
/// of the SASS file(s).
consumeTransitiveSassDeps(
    Transform transform, Asset asset,
    [Set<AssetId> visitedIds]) async {
  visitedIds ??= new Set<AssetId>();
  if (visitedIds != null && !visitedIds.add(asset.id)) return;

  // TODO(ochafik): Handle .sass files?
  var sass = await asset.readAsString();
  var futures = <Future>[];
  for (var match in _importRx.allMatches(sass)) {
    var url = match.group(1);
    if (!url.endsWith('.scss')) {
      // Expand sass partial: foo/bar -> foo/_bar.scss
      var split = url.split('/');
      split[split.length - 1] = '_${split.last}.scss';
      url = split.join('/');
    }
    futures.add((() async {
      try {
        var importedAsset = await resolveAsset(transform, url, asset.id);
        consumeTransitiveSassDeps(transform, importedAsset, visitedIds);
      } catch (e, s) {
        transform.logger.warning(
            "Failed to resolve import of '$url' from ${asset.id}: $e");
      }
    })());
  }
  await Future.wait(futures);
}

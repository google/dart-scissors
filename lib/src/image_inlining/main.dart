library scissors.src.image_inlining.main;

import 'dart:io';
import 'package:scissors/src/image_inlining/image_inliner.dart';
import 'package:barback/barback.dart'
    show Asset, AssetId, AssetNotFoundException;
import 'package:path/path.dart';
import 'package:scissors/src/utils/path_resolver.dart';
import 'dart:async';

const _package = 'file';

main(List<String> args) async {
  var includeDirs = <String>[];
  File input;
  File output;
  for (int i = 0, n = args.length; i < n; i++) {
    var arg = args[i];
    if (arg == '-I') {
      includeDirs.add(args[++i]);
    } else {
      if (input == null) input = new File(arg);
      else if (output == null) output = new File(arg);
      else throw new ArgumentError('Unexpected: $arg');
    }
  }

  if (output == null) {
    throw new ArgumentError('Expected (-I path)* input output');
  }

  makeFileAsset(File file) {
    var path = relative(file.path, from: Directory.current.path);
    return new Asset.fromFile(new AssetId(_package, path), new File(path));
  }

  var assets = <AssetId, Future<Asset>>{};
  Future<Asset> getAsset(AssetId id) => assets.putIfAbsent(id, () async {
        var path = id.path;

        var file = new File(path);
        if (await file.exists()) return makeFileAsset(file);

        for (var dir in includeDirs) {
          var file = new File(join(dir, path));
          if (await file.exists()) return makeFileAsset(file);
        }
        throw new AssetNotFoundException(id);
      });

  var result = await inlineImages(
      makeFileAsset(input), ImageInliningMode.inlineInlinedImages,
      assetFetcher: (String url, {AssetId from}) {
    var alternativeUrls = [url]..addAll(includeDirs.map(((d) => join(d, url))));
    return pathResolver.resolveAsset(getAsset, alternativeUrls, from);
  });

  var stream = result.css.read();
  if (output.path == '-') stream.pipe(stdout);
  else stream.pipe(output.openWrite());
}

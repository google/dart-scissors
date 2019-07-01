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
  var includeDirs = <Directory>[];
  File input;
  File output;
  for (int i = 0, n = args.length; i < n; i++) {
    var arg = args[i];
    if (arg == '-I') {
      includeDirs.add(new Directory(args[++i]));
    } else {
      if (input == null)
        input = new File(arg);
      else if (output == null)
        output = new File(arg);
      else
        throw new ArgumentError('Unexpected: $arg');
    }
  }

  if (output == null) {
    throw new ArgumentError('Expected (-I path)* input output');
  }

  var stream =
      (await inlineImagesWithIncludeDirs(makeFileAsset(input), includeDirs))
          .read();
  if (output.path == '-')
    await stream.cast<List<int>>().pipe(stdout);
  else
    await stream.cast<List<int>>().pipe(output.openWrite());
}

Asset makeFileAsset(File file) {
  var path = relative(file.path, from: Directory.current.path);
  return new Asset.fromFile(new AssetId(_package, path), new File(path));
}

Asset makeStringAsset(String path, String input) {
  return new Asset.fromString(new AssetId(_package, path), input);
}

/// Returns null if the input didn't have any inline-image() call.
Future<Asset> inlineImagesWithIncludeDirs(
    Asset input, List<Directory> includeDirs) async {
  var assets = <AssetId, Future<Asset>>{};
  Future<Asset> getAsset(AssetId id) => assets.putIfAbsent(id, () async {
        var path = id.path;

        var file = new File(path);
        if (await file.exists()) return makeFileAsset(file);

        for (var dir in includeDirs) {
          var file = new File(join(dir.path, path));
          if (await file.exists()) return makeFileAsset(file);
        }
        throw new AssetNotFoundException(id);
      });

  var result = await inlineImages(input, ImageInliningMode.inlineInlinedImages,
      assetFetcher: (String url, {AssetId from}) {
    var alternativeUrls = [url]
      ..addAll(includeDirs.map(((d) => join(d.path, url))));
    return pathResolver.resolveAsset(getAsset, alternativeUrls, from);
  });

  if (result.success && result.css == null) {
    // inlineImage fast-failed.
    return input;
  }

  return result.css;
}

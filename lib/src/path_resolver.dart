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
library scissors.path_resolver;

import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:barback/barback.dart' show Asset, AssetId, Transform;

Future<String> resolvePath(String path) async {
  // Note: this file is meant to be replaced by custom resolution logic in
  // forks of this package.
  return new Future.value(path);
}

Future<Asset> resolveAsset(Transform transform, String url, AssetId from) {
  var id = new AssetId(from.package, join(dirname(from.path), url));
  return transform.getInput(id);
}

Future<List<String>> getRootDirectories() async {
  return [Directory.current.path];
}

Future<String> resolveAssetFile(AssetId id) async {
  var path = id.path;
  if (path.startsWith('lib/')) path = path.substring('lib/'.length);

  return join('packages', id.package.replaceAll('.', '/'), path);
}

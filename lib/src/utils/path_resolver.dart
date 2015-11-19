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
library scissors.src.utils.path_resolver;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:barback/barback.dart'
    show Asset, AssetId, AssetNotFoundException, Transform;

import 'path_utils.dart';

/// Customization entry point for forks of this library.
PathResolver pathResolver = new PathResolver();

final RegExp _packageUrlRx = new RegExp(r'^package:(\w+)/(.*)$');

AssetId _parsePackageUrl(String url) {
  var m = _packageUrlRx.matchAsPrefix(url);
  if (m == null) throw new FormatException('Invalid url format: $url');

  return new AssetId(m[1], 'lib/${m[2]}');
}

class PathResolver {
  final String defaultJavaPath = 'java';
  final String defaultSassCPath = 'sassc';
  final String defaultPngCrushPath = 'pngcrush';
  final String defaultCssJanusPath = 'cssjanus';
  final String defaultJRubyPath = 'jruby';
  final String defaultRubySassPath = 'sass';
  final String defaultCompassStylesheetsPath = null;
  final String defaultClosureCompilerJarPath = 'compiler.jar';

  Future<String> resolvePath(String path) async {
    // Note: this file is meant to be replaced by custom resolution logic in
    // forks of this package.
    return (await _resolveFileAsset([path]))?.file?.path ?? path;
  }

  Future<Asset> resolveAsset(Future<Asset> inputGetter(AssetId id),
      Iterable<String> alternativePaths, AssetId from) async {
    // First, try package URIs:
    for (var path in alternativePaths) {
      if (path.contains(':')) {
        try {
          return inputGetter(_parsePackageUrl(path));
        } catch (e) {
          // Do nothing.
        }
      }
    }
    // First, try relative paths:
    var parent = dirname(from.path);
    Iterable<AssetId> ids = alternativePaths
        .map((path) => new AssetId(from.package, join(parent, path)));
    Asset asset = await findFirstWhere(
        ids.map(inputGetter).toList(),
        (Future<Asset> asset) => asset.then((_) => true, onError: (e, [s]) {
              acceptAssetNotFoundException(e, s);
              return false;
            }));
    if (asset != null) return asset;

    var paths = []..addAll(alternativePaths);
    if (from != null) {
      var parent = dirname(from.path);
      if (from.package != _filePseudoPackage) {
        parent = join(from.package.replaceAll('.', '/'), parent);
      }
      paths.addAll(alternativePaths.map((u) => join(parent, u)));
    }
    var resolved = await _resolveFileAsset(paths);
    if (resolved != null) {
      return resolved.toAsset();
    }
    throw new AssetNotFoundException(ids.first);
  }

  final Future<List<Directory>> _rootDirectories =
      new Future.value(<Directory>[Directory.current]);

  Future<List<Directory>> getRootDirectories() => _rootDirectories;

  List<Directory> _sassIncludeDirectories;
  Future<List<Directory>> getSassIncludeDirectories() async {
    if (_sassIncludeDirectories == null) {
      var roots = await getRootDirectories();
      _sassIncludeDirectories = []..addAll(roots);
      if (defaultCompassStylesheetsPath == null) {
        // Import compass' SASS partials.
        var compassDirs = findExistingDirectories(roots
            .map((d) => new File(join(d.path, defaultCompassStylesheetsPath))));
        await for (var dir in compassDirs) {
          _sassIncludeDirectories.add(dir);
        }
      }
    }
    return _sassIncludeDirectories;
  }

  Future<File> resolveAssetFile(AssetId id) async {
    var alternativePaths = [
      join(id.package.replaceAll('.', '/'), id.path),
      id.path
    ];
    var path =
        id.path.startsWith('lib/') ? id.path.substring('lib/'.length) : id.path;
    alternativePaths
        .add(join('packages', id.package.replaceAll('.', '/'), path));

    var fileAsset = await _resolveFileAsset(alternativePaths);
    if (fileAsset == null) throw new AssetNotFoundException(id);

    return fileAsset.file;
  }

  Future<_FileAsset> _resolveFileAsset(List<String> alternativePaths) async {
    var assets = <_FileAsset>[];
    for (var dir in await getRootDirectories()) {
      for (var path in alternativePaths) {
        assets.add(new _FileAsset(dir, path));
      }
    }
    return findFirstWhere(assets, (a) => a.file.exists());
  }

  String assetIdToUri(AssetId id) {
    var path = id.path;
    if (path.startsWith('lib/')) path = path.substring('lib/'.length);
    return 'package:${id.package}/$path';
  }
}

const _filePseudoPackage = '_';

class _FileAsset {
  Directory rootDir;
  File file;
  String path;
  _FileAsset(this.rootDir, this.path) {
    file = new File(join(rootDir.path, path));
  }
  Asset toAsset() =>
      new Asset.fromFile(new AssetId(_filePseudoPackage, path), file);
  toString() => file.path;
}

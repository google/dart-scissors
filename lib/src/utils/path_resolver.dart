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
import 'package:scissors/src/utils/process_utils.dart';

/// Customization entry point for forks of this library.
PathResolver pathResolver = new PathResolver();

final RegExp _packageUrlRx = new RegExp(r'^package:(\w+)/(.*)$');

AssetId _parsePackageUrl(String url) {
  var m = _packageUrlRx.matchAsPrefix(url);
  if (m == null) throw new FormatException('Invalid url format: $url');

  return new AssetId(m[1], 'lib/${m[2]}');
}

class PathResolver {
  final String defaultJavaPath = Platform.environment['JAVA_BIN'] ?? 'java';
  final String defaultSassCPath = Platform.environment['SASSC_BIN'] ?? 'sassc';
  final String defaultRubySassPath = Platform.environment['SASS_BIN'] ?? 'sass';
  final String defaultPngCrushPath =
      Platform.environment['PNGCRUSH_BIN'] ?? 'pngcrush';
  final String defaultCssJanusPath =
      Platform.environment['CSSJANUS_BIN'] ?? 'cssjanus.py';
  final String defaultRubyPath = Platform.environment['RUBY_BIN'] ?? 'ruby';
  final String defaultCompassStylesheetsPath = null;
  final String defaultClosureCompilerJarPath =
      Platform.environment['CLOSURE_COMPILER_BIN'] ?? 'compiler.jar';
  final String defaultGemPath = Platform.environment['RUBY_GEM_BIN'] ?? 'gem';

  Future<String> resolvePath(String path) async {
    if (path == null) return null;
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

  Future<Map<String, Directory>> _packageLibDirectories;
  Future<Map<String, Directory>> getPackageLibDirectories() {
    if (_packageLibDirectories == null) {
      _packageLibDirectories = (() async {
        var map = {};
        var rootDirs = await getRootDirectories();
        File packagesFile = await findFirstWhere(
            rootDirs.map((d) => new File(join(d.path, '.packages'))).toList(),
            (f) => f.exists());
        var content = await packagesFile.readAsString();
        for (var line in content.split('\n')) {
          line = line.trim();
          if (line.startsWith('#') || line == '') continue;

          int i = line.indexOf(':');
          if (i < 0) continue;

          var package = line.substring(0, i);
          var uri = line.substring(i + 1);
          var dir;
          if (!uri.contains(":")) {
            dir = new Directory(
                isAbsolute(uri) ? uri : join(dirname(packagesFile.path), uri));
          } else {
            dir = new Directory(Uri.parse(uri).path);
          }
          map[package] = dir;
        }
        return map;
      })();
    }
    return _packageLibDirectories;
  }

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
    var packageLibDirectories = await getPackageLibDirectories();
    var libDir = packageLibDirectories[id.package];
    if (libDir != null && await libDir.exists()) {
      var file = new File(join(libDir.path, '..', id.path));
      if (await file.exists()) {
        return file;
      }
    }
    throw new AssetNotFoundException(id);
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

  Future<String> resolveExecutable(String path) async {
    path = await resolvePath(path);
    if (!await new File(path).exists()) {
      path = which(path).trim();
    }
    return path;
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

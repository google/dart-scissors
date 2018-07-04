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
    show Asset, AssetId, AssetNotFoundException;

import 'path_utils.dart';
import '../utils/process_utils.dart';
import 'package:scissors/src/utils/enum_parser.dart';

export 'global_path_resolver.dart' show pathResolver;

enum ExtensionMode { replace, append }

final parseExtensionMode =
    new EnumParser<ExtensionMode>(ExtensionMode.values).parse;

final RegExp _packageUrlRx = new RegExp(r'^package:(\w+)/(.*)$');

AssetId _parsePackageUrl(String url) {
  var m = _packageUrlRx.matchAsPrefix(url);
  if (m == null) throw new FormatException('Invalid url format: $url');

  return new AssetId(m[1], 'lib/${m[2]}');
}

class PathResolver {
  ExtensionMode get defaultCompiledCssExtensionMode => ExtensionMode.append;
  String get defaultJavaPath => Platform.environment['JAVA_BIN'] ?? 'java';
  String get defaultSassCPath => Platform.environment['SASSC_BIN'] ?? 'sassc';
  String get defaultRubySassPath => Platform.environment['SASS_BIN'] ?? 'sass';
  String get defaultPngCrushPath =>
      Platform.environment['PNGCRUSH_BIN'] ?? 'pngcrush';
  String get defaultCssJanusPath =>
      Platform.environment['CSSJANUS_BIN'] ?? 'cssjanus.py';
  String get defaultRubyPath => Platform.environment['RUBY_BIN'] ?? 'ruby';
  String get defaultCompassStylesheetsPath => null;
  String get defaultClosureCompilerJarPath =>
      Platform.environment['CLOSURE_COMPILER_JAR'] ??
      '.dependencies/compiler.jar';
  String get defaultGemPath => Platform.environment['RUBY_GEM_BIN'] ?? 'gem';

  Future<String> resolvePath(String path) async {
    if (path == null) return null;
    return (await _resolveFileAsset([path]))?.fullPath ?? path;
  }

  Future<Asset> resolveAsset(Future<Asset> inputGetter(AssetId id),
      Iterable<String> alternativePaths, AssetId from) async {
    // First, try package URIs:
    for (var path in alternativePaths) {
      if (path.contains(':')) {
        try {
          if (path.startsWith('/')) path = path.substring(1);
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
    // Two awaits required in Dart 2 semantics. Which conflicts with await_only_futures.
    // https://github.com/dart-lang/linter/issues/992
    // ignore: await_only_futures
    Asset asset = await await findFirstWhere<Future<Asset>>(ids.map(inputGetter).toList(),
        (Future<Asset> asset) async {
      try {
        await asset;
        return true;
      } on AssetNotFoundException catch (_) {
        return false;
      }
    });
    if (asset != null) return asset;

    var paths = <String>[]..addAll(alternativePaths);
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
            (File f) => f.exists());
        if (packagesFile != null) {
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
              dir = new Directory(isAbsolute(uri)
                  ? uri
                  : join(dirname(packagesFile.path), uri));
            } else {
              dir = new Directory(Uri.parse(uri).path);
            }
            map[package] = dir;
          }
        }
        return map;
      })();
    }
    return _packageLibDirectories;
  }

  Future<List<Directory>> _sassIncludeDirectories;
  Future<List<Directory>> getSassIncludeDirectories() =>
      _sassIncludeDirectories ??= _getSassIncludeDirectories();

  Future<List<Directory>> _getSassIncludeDirectories() async {
    var roots = await getRootDirectories();
    var dirs = <Directory>[]..addAll(roots);
    if (defaultCompassStylesheetsPath != null) {
      // Import compass' SASS partials.
      var compassDirs = findExistingDirectories(roots.map(
          (d) => new Directory(join(d.path, defaultCompassStylesheetsPath))));
      await for (var dir in compassDirs) {
        dirs.add(dir);
      }
    }
    return dirs;
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
    return new File(fileAsset.fullPath);
  }

  Future<_FileAsset> _resolveFileAsset(List<String> alternativePaths) async {
    var assets = <_FileAsset>[];
    for (var dir in await getRootDirectories()) {
      for (var path in alternativePaths) {
        assets.add(new _FileAsset(dir, path));
      }
    }
    return findFirstWhere(assets, (_FileAsset a) => a.exists());
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
  String fullPath;
  String path;
  _FileAsset(this.rootDir, this.path) {
    fullPath = join(rootDir.path, path);
  }

  Future<bool> exists() async =>
      (await FileStat.stat(fullPath)).type != FileSystemEntityType.NOT_FOUND;

  Asset toAsset() => new Asset.fromFile(
      new AssetId(_filePseudoPackage, path), new File(fullPath));
  toString() => fullPath;
}

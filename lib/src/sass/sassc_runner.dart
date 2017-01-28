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
library scissors.src.sass.sassc;

import 'dart:async';
import 'dart:io';

import 'package:barback/barback.dart'
    show Asset, AssetId, AssetNotFoundException, LogLevel;
import 'package:path/path.dart';
import 'package:source_span/source_span.dart';

import '../utils/path_resolver.dart';
import '../utils/result.dart' show TransformMessage, TransformResult;
import 'package:quiver/check.dart';

class SasscSettings {
  final String sasscPath;
  final List<String> sasscArgs;
  final List<Directory> sasscIncludes;
  final ExtensionMode compiledCssExtensionMode;

  SasscSettings(this.sasscPath, this.sasscArgs, this.sasscIncludes,
      this.compiledCssExtensionMode);

  AssetId getCssOutputId(AssetId sassId) {
    var ext = sassId.extension;
    checkArgument(ext == '.sass' || ext == '.scss',
        message: () => "Invalid Sass extension: $ext");
    switch (compiledCssExtensionMode) {
      case ExtensionMode.append:
        return sassId.addExtension('.css');
      case ExtensionMode.replace:
        return sassId.changeExtension('.css');
      default:
        throw new StateError(
            'Invalid extension mode: $compiledCssExtensionMode');
    }
  }
}

Future<TransformResult> runSassC(Asset sassAsset,
    {bool isDebug, SasscSettings settings}) async {
  var sassId = sassAsset.id;
  Future<String> sassContentFuture;
  getSassContent() {
    sassContentFuture ??= sassAsset.readAsString();
    return sassContentFuture;
  }

  // Each run gets its temp dir.
  var dir = await Directory.systemTemp.createTemp();
  try {
    List<String> cmd;
    var fileName = basename(sassId.path);
    var sassFile;
    try {
      sassFile = (await pathResolver.resolveAssetFile(sassId)).absolute;
    } on AssetNotFoundException catch (_) {
      sassFile = new File(join(dir.path, fileName));
      await sassFile.writeAsString(await getSassContent());
    }
    var cssFile = new File(join(dir.path, fileName + ".css"));
    var mapFile = new File(cssFile.path + ".map");

    // TODO(ochafik): What about `sassc -t nested`?
    var args = <String>[];
    args..add('-t')..add(isDebug ? 'expanded' : 'compressed');
    if (!isDebug) args.add('--omit-map-comment');
    args.add('-m');
    args.add(relative(sassFile.path, from: dir.path));
    args.add(relative(cssFile.path, from: dir.path));
    args.addAll(settings.sasscArgs);
    var path = settings.sasscPath;
    cmd = [path]..addAll(args);

    // print('Running $cmd in $dir');
    var result = await Process.run(path, args, workingDirectory: dir.path);

    var messages = <TransformMessage>[];
    /*
    Error: invalid property name
            on line 1 of foo.scss
    >>       .foo {{
       -----------^
    */
    var primaryFile = relative(sassFile.path, from: cssFile.path);
    var messageRx = new RegExp(
        r'(Error|Warning|Info): (.*?)\n'
        r'\s+on line (\d+) of (.*?)\n'
        r'>> (.*?)\n'
        r'   (-*\^)$',
        multiLine: true);
    convertLevel(String level) {
      switch (level) {
        case 'Error':
          return LogLevel.ERROR;
        case 'Warning':
          return LogLevel.WARNING;
        case 'Info':
          return LogLevel.INFO;
        default:
          throw new StateError("Unknown level: $level");
      }
    }

    for (var match in messageRx.allMatches(result.stderr)) {
      var level = match.group(1);
      var message = match.group(2);
      int line = int.parse(match.group(3));
      var file = normalize(match.group(4));
      var excerpt = match.group(5);
      var arrow = match.group(6);

      if (file == relative(sassFile.path, from: dir.path)) {
        int column = arrow.length;
        var start =
            _computeSourceSpan(await getSassContent(), '$sassId', line, column);
        var span;
        if (start != null) {
          var end = new SourceLocation(start.offset + excerpt.length,
              sourceUrl: start.sourceUrl,
              line: line,
              column: column + excerpt.length);
          span = new SourceSpan(start, end, excerpt);
        }
        messages.add(
            new TransformMessage(convertLevel(level), message, sassId, span));
      } else {
        // TODO(ochafik): Compute asset + span from file if possible here.
        var asset;
        var span;
        message += '\nIn $file:$line\n  $excerpt\n  $arrow';
        messages.add(
            new TransformMessage(convertLevel(level), message, asset, span));
      }
    }

    if (result.exitCode == 0) {
      var map = await mapFile.readAsString();
      map = map.replaceAll(primaryFile, fileName);

      var cssId = settings.getCssOutputId(sassId);
      return new TransformResult(
          true,
          messages,
          new Asset.fromString(cssId, await cssFile.readAsString()),
          new Asset.fromString(cssId.addExtension('.map'), map));
    } else {
      if (!messages.any((m) => m.level == LogLevel.ERROR)) {
        messages.add(new TransformMessage(
            LogLevel.ERROR,
            "Failed to run $cmd in ${dir.path}:\n${result.stderr}",
            null,
            null));
      }
      return new TransformResult(false, messages, null, null);
    }
  } finally {
    await dir.delete(recursive: true);
  }
}

final _multilineRx = new RegExp(r'^.*?$', multiLine: true);

SourceLocation _computeSourceSpan(
    String content, String sourceUrl, int line, int column) {
  int nextLine = 1;
  for (var match in _multilineRx.allMatches(content)) {
    if (line == nextLine) {
      var offset = match.start + column - 1;
      return new SourceLocation(offset,
          sourceUrl: sourceUrl, line: line, column: column);
    }
    nextLine++;
  }
  throw new StateError("No such position in file: line $line, column $column");
}

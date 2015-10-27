library scissors.sassc;

import 'dart:async';
import 'dart:io';

import 'package:barback/barback.dart' show Asset, AssetId, LogLevel, Transform;
import 'package:code_transformers/messages/build_logger.dart';
import 'package:path/path.dart';
import 'package:source_span/source_span.dart';
import 'path_resolver.dart' show resolveAssetFile;

class SassMessage {
  final LogLevel level;
  final String message;
  final AssetId asset;
  final SourceSpan span;
  SassMessage(this.level, this.message, this.asset, this.span);

  log(Transform transform) {
    var logger = new BuildLogger(transform, primaryId: asset);
    switch (level) {
      case LogLevel.ERROR:
        logger.error(message, asset: asset, span: span);
        break;
      case LogLevel.WARNING:
        logger.warning(message, asset: asset, span: span);
        break;
      case LogLevel.INFO:
        logger.info(message, asset: asset, span: span);
        break;
    }
  }
}

class SassResult {
  final bool success;
  final List<SassMessage> messages;
  final Asset css;
  final Asset map;
  SassResult(this.success, this.messages, this.css, this.map);
}

class SasscSettings {
  final String sasscPath;
  final List<String> sasscArgs;

  SasscSettings(this.sasscPath, this.sasscArgs);
}

// Each isolate gets its temp dir.
var _tmpDir = Directory.systemTemp.createTemp();

Future<SassResult> runSassC(Asset sassAsset,
    {bool isDebug, SasscSettings settings}) async {

  var sassId = sassAsset.id;
  Future<String> sassContentFuture;
  getSassContent() {
    sassContentFuture ??= sassAsset.readAsString();
    return sassContentFuture;
  }
  var dir = await _tmpDir;
  List<String> cmd;
  {
    var fileName = basename(sassId.path);
    var sassFile = new File(absolute(await resolveAssetFile(sassId)));
    if (!await sassFile.exists()) {
      sassFile = new File(join(dir.path, fileName));
      await sassFile.writeAsString(await getSassContent());
    }
    var cssFile = new File(join(dir.path, fileName + ".css"));
    var mapFile = new File(cssFile.path + ".map");

    // TODO(ochafik): What about `sassc -t nested`?
    var args = [
      '-t', isDebug ? 'expanded' : 'compressed',
      '-m',
      relative(sassFile.path, from: dir.path),
      relative(cssFile.path, from: dir.path)
    ];
    args.addAll(settings.sasscArgs);
    var path = settings.sasscPath;
    cmd = [path]..addAll(args);

    var result = await Process.run(path, args, workingDirectory: dir.path);

    var messages = <SassMessage>[];
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
        case 'Error': return LogLevel.ERROR;
        case 'Warning': return LogLevel.WARNING;
        case 'Info': return LogLevel.INFO;
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
        var start = _computeSourceSpan(
            await getSassContent(), '$sassId', line, column);
        var span;
        if (start != null) {
          var end = new SourceLocation(
              start.offset + excerpt.length,
              sourceUrl: start.sourceUrl,
              line: line, column: column + excerpt.length);
          span = new SourceSpan(start, end, excerpt);
        }
        messages.add(new SassMessage(convertLevel(level), message, sassId, span));
      } else {
        // TODO(ochafik): Compute asset + span from file if possible here.
        var asset = null;
        var span = null;
        message += '\nIn $file:$line\n  $excerpt\n  $arrow';
        messages.add(new SassMessage(convertLevel(level), message, asset, span));
      }
    }

    if (result.exitCode == 0) {
      var map = await mapFile.readAsString();
      map = map.replaceAll(primaryFile, fileName);

      return new SassResult(true, messages,
          new Asset.fromFile(sassId.addExtension('.css'), cssFile),
          new Asset.fromString(sassId.addExtension('.css.map'), map));
    } else {
      if (!messages.any((m) => m.level == LogLevel.ERROR)) {
        messages.add(new SassMessage(LogLevel.ERROR,
            "Failed to run $cmd in ${dir.path}:\n${result.stderr}", null, null));
      }
      return new SassResult(false, messages, null, null);
    }
  }
}

final _multilineRx = new RegExp(r'^.*?$', multiLine: true);

SourceLocation _computeSourceSpan(String content, String sourceUrl, int line, int column) {
  int nextLine = 1;
  for (var match in _multilineRx.allMatches(content)) {
    if (line == nextLine) {
      var offset = match.start + column - 1;
      return new SourceLocation(offset, sourceUrl: sourceUrl, line: line, column: column);
    }
    nextLine++;
  }
  throw new StateError("No such position in file: line $line, column $column");
}

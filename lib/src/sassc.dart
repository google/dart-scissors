library scissors.sassc;

import 'dart:async';
import 'dart:io';

import 'package:barback/barback.dart' show Asset, AssetId, LogLevel, Transform;
import 'package:code_transformers/messages/build_logger.dart';
import 'package:path/path.dart';
import 'package:source_span/source_span.dart';

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

Future<SassResult> runSassC(Asset sassAsset,
    {bool isDebug,
     Future<String> sasscPath,
     Future<List<String>> sasscArgs}) async {

  var sassId = sassAsset.id;
  var sassContent = sassAsset.readAsString();
  var dir = await Directory.systemTemp.createTemp();
  List<String> cmd;
  try {
    var fileName = basename(sassId.path);
    var sassFile = new File(join(dir.path, fileName));
    var cssFile = new File(sassFile.path + ".css");
    var mapFile = new File(cssFile.path + ".map");

    await sassFile.writeAsString(await sassContent);

    // TODO(ochafik): What about `sassc -t nested`?
    var args = [
      '-t', isDebug ? 'expanded' : 'compressed',
      '-m',
      relative(sassFile.path, from: dir.path),
      relative(cssFile.path, from: dir.path)
    ];
    args.addAll(await sasscArgs);
    var path = await sasscPath;
    cmd = [path]..addAll(args);

    var result = await Process.run(path, args, workingDirectory: dir.path);

    var messages = <SassMessage>[];
    /*
    Error: invalid property name
            on line 1 of foo.scss
    >>       .foo {{
       -----------^
    */
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

      if (file == basename(sassId.path)) {
        int column = arrow.length;
        var start = _computeSourceSpan(await sassContent, '$sassId', line, column);
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
      var css = cssFile.readAsString();
      var map = mapFile.readAsString();
      var ext = sassId.extension;
      return new SassResult(true, messages,
          new Asset.fromString(sassId.changeExtension('$ext.css'), await css),
          new Asset.fromString(sassId.changeExtension('$ext.css.map'), await map));
    } else {
      if (!messages.any((m) => m.level == LogLevel.ERROR)) {
        messages.add(new SassMessage(LogLevel.ERROR,
            "Failed to run $cmd in ${dir.path}:\n${result.stderr}", null, null));
      }
      return new SassResult(false, messages, null, null);
    }
  } finally {
    await _deleteDir(dir);
  }
}

_deleteDir(Directory dir) async {
  await for (var f in dir.list()) {
    await f.delete();
  }
  await dir.delete();
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

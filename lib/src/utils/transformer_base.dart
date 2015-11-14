library scissors.src.utils.perf;
import 'package:barback/barback.dart';
import 'dart:async';

abstract class TransformerBase {
  time(Transform transform, String title, Future action()) async {
    var stopwatch = new Stopwatch()..start();
    try {
      // transform.logger.info('$title...');
      return await action();
    } finally {
      transform.logger
          .info('$title took ${stopwatch.elapsed.inMilliseconds} msec.');
    }
  }

  final RegExp _filesToSkipRx =
      new RegExp(r'^_.*?\.scss|.*?\.ess\.s[ac]ss\.css(\.map)?$');

  bool shouldSkipAsset(AssetId id) {
    var name = basename(id.path);
    return _filesToSkipRx.matchAsPrefix(name) != null;
  }
}

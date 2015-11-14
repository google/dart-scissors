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

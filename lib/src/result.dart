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
library scissors.result;

import 'package:barback/barback.dart' show Asset, AssetId, LogLevel, Transform;
import 'package:code_transformers/messages/build_logger.dart';
import 'package:source_span/source_span.dart';

class TransformMessage {
  final LogLevel level;
  final String message;
  final AssetId asset;
  final SourceSpan span;
  TransformMessage(this.level, this.message, this.asset, this.span);

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

class TransformResult {
  final Asset css;
  final Asset map;
  final bool success;
  final List<TransformMessage> messages;
  TransformResult(this.success,
      [this.messages = const <TransformMessage>[], this.css, this.map]);

  void logMessages(Transform transform) {
    messages.forEach((m) => m.log(transform));
  }
}

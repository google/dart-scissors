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
library scissors.src.js_optimization.optimization;

import 'dart:async';
import 'dart:io';

import 'package:barback/barback.dart';

import '../utils/delta_format.dart';
import '../utils/path_resolver.dart';
import 'closure.dart';
import 'settings.dart';

Future<Asset> optimizeJsAsset(TransformLogger logger, Asset input,
    JsOptimizationSettings settings) async {
  var content = await input.readAsString();
  var javaPath = settings.javaPath.value;
  var path =
      await pathResolver.resolvePath(settings.closureCompilerJarPath.value);
  if (!await new File(path).exists()) {
    throw new StateError("Did not find Closure Compiler ($path)");
  }
  var result = await simpleClosureCompile(javaPath, path, content);
  logger.info(
      'Ran Closure Compiler: ${formatDeltaChars(content.length, result.length)}',
      asset: input.id);

  return new Asset.fromString(input.id, result);
}

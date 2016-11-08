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
library scissors.src.image_optimization.png_optimizer;

import 'dart:async';
import 'dart:io';

import 'package:barback/barback.dart' show Asset;
import 'package:path/path.dart';

import '../utils/io_utils.dart';

var _tempDir = Directory.systemTemp.createTemp();
var nextFileId = 1;

Future<Asset> runPngCrush(String pngCrushPath, Asset input,
    sizeReport(int originalSize, int resultSize)) async {
  var dir = await _tempDir;
  var fileName = basename(input.id.path);
  var inputFile = new File(join(dir.path, fileName));
  var outputFile = new File(join(dir.path, '$fileName-${nextFileId++}.out'));

  await inputFile.writeAsBytes(await readAll(input.read()));

  var args = "-q -brute -reduce "
      "-rem alla -rem allb "
      "-rem gAMA -rem cHRM -rem iCCP -rem sRGB -rem text -rem time";
  ProcessResult result = await Process.run(
      pngCrushPath,
      []
        ..addAll(args.split(' '))
        ..add(inputFile.path)
        ..add(outputFile.path));
  print(result.stdout);
  if (result.exitCode != 0) {
    throw new ArgumentError('Failed to crush ${input.id}:\n${result.stderr}');
  }

  sizeReport(inputFile.lengthSync(), outputFile.lengthSync());

  return new Asset.fromFile(input.id, outputFile);
}

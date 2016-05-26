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
library scissors.src.utils.io_utils;

import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';

Future<List<int>> readAll(Stream<List<int>> data) async => (await data.fold(
        new BytesBuilder(), (BytesBuilder builder, data) => builder..add(data)))
    .takeBytes();

List<int> readStdinSync() {
  final List<int> input = <int>[];
  while (true) {
    int byte = stdin.readByteSync();
    if (byte < 0) {
      if (input.isEmpty) return null;
      break;
    }
    input.add(byte);
  }
  return input;
}

Directory _tempDir;
Directory get tempDir => _tempDir ??= Directory.systemTemp.createTempSync();

File makeTempFile(String name, List<int> content) =>
    new File(join(tempDir.path, name))..writeAsBytesSync(content);

void deleteTempDir() {
  if (_tempDir == null) return;
  var d = _tempDir;
  _tempDir = null;
  d.listSync().forEach((f) => f.deleteSync());
  d.deleteSync();
}

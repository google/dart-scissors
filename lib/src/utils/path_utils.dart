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
library scissors.src.utils.path_utils;

import 'dart:async';
import 'dart:io';

import 'package:barback/barback.dart' show AssetNotFoundException;

Stream<Directory> findExistingDirectories(Iterable<FileSystemEntity> dirs,
    {bool followLinks: true}) async* {
  Future<Directory> resolve(FileSystemEntity dir) async {
    if (await dir.exists()) return dir;
    if (followLinks && (await dir.stat()).type == FileSystemEntityType.LINK) {
      return resolve(new Directory(await (new Link(dir.path)).target()));
    }
    return null;
  }

  for (var dir in await Future.wait(dirs.map(resolve))) {
    if (dir != null) yield dir;
  }
}

Future<T> findFirstWhere<T>(List<T> values, Future<bool> predicate(T value),
    {T orElse}) async {
  int i = 0;
  // Parallelize the predicates evaluation.
  for (var future in values.map(predicate).toList()) {
    try {
      if (await future) return values[i];
    } on AssetNotFoundException catch (_) {
      // Do nothing.
    }
    i++;
  }
  return orElse;
}

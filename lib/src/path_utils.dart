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
library scissors.src.path_utils;

import 'dart:async';
import 'dart:io';
import 'package:barback/barback.dart' show AssetNotFoundException;

Stream<Directory> findExistingDirectories(Iterable<Directory> dirs) async* {
  List<Future<File>> futures =
      dirs.map((dir) async => await dir.exists() ? dir : null).toList();
  for (var future in futures) {
    var dir = await future;
    if (dir != null) yield dir;
  }
}

Future findFirstWhere(List values, Future<bool> predicate(dynamic value),
    {orElse}) async {
  int i = 0;
  // Parallelize the predicates evaluation.
  for (var future in values.map(predicate).toList()) {
    try {
      if (await future) return values[i];
    } catch (_) {}
    i++;
  }
  return orElse;
}

acceptAssetNotFoundException(e, s) {
  if (e is! AssetNotFoundException) {
    throw new StateError('$e (${e.runtimeType})\n$s');
  }
}

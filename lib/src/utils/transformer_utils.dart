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
import 'dart:async';

import 'package:barback/barback.dart';

Future<Map<String, T>> _getInput<T>(
    Stream<T> values, AssetId getId(T value)) async {
  var res = <String, T>{};
  await for (final value in values) {
    final id = getId(value);
    res[id.extension] = value;
  }
  return res;
}

Future<Map<String, AssetId>> getDeclaredInputs(
        DeclaringAggregateTransform transform) =>
    _getInput<AssetId>(transform.primaryIds, (id) => id);

Future<Map<String, Asset>> getInputs(AggregateTransform transform) =>
    _getInput<Asset>(transform.primaryInputs, (asset) => asset.id);

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
library scissors.src.utils.lazy_transformer_utils;

import 'package:barback/barback.dart';

class LazyTransformerWrapper implements Transformer, LazyTransformer {
  final Transformer _transformer;
  LazyTransformerWrapper(this._transformer);

  @override
  String get allowedExtensions => _transformer.allowedExtensions;

  @override
  apply(Transform transform) => _transformer.apply(transform);

  @override
  declareOutputs(DeclaringTransform transform) =>
      (_transformer as DeclaringTransformer).declareOutputs(transform);

  @override
  isPrimary(AssetId id) => _transformer.isPrimary(id);

  @override
  toString() => _transformer.toString();
}

class LazyTransformerGroupWrapper implements TransformerGroup {
  final TransformerGroup group;
  Iterable<Iterable> _phases;
  LazyTransformerGroupWrapper(this.group) {
    _phases = group.phases
        .map((ts) => ts.map((t) => new LazyTransformerWrapper(t)))
        .toList();
  }

  @override
  Iterable<Iterable> get phases => _phases;

  @override
  toString() => group.toString();
}

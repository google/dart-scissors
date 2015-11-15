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
library scissors.src.utils.lazywrapped_utils;

import 'package:barback/barback.dart';
import 'package:quiver/check.dart';

abstract class LazyTransformerWrapper {
  final wrapped;
  LazyTransformerWrapper._(this.wrapped);

  factory LazyTransformerWrapper(wrapped) {
    return wrapped is AggregateTransformer
        ? new _LazyAggregateTransformerWrapper(wrapped)
        : new _LazyTransformerWrapper(wrapped);
  }

  @override
  toString() => wrapped.toString();
}

class _LazyTransformerWrapper extends LazyTransformerWrapper
    implements Transformer, LazyTransformer {
  Transformer get wrapped => super.wrapped;
  _LazyTransformerWrapper(Transformer wrapped) : super._(wrapped) {
    checkState(wrapped is Transformer);
  }

  @override
  String get allowedExtensions => wrapped.allowedExtensions;

  @override
  apply(Transform transform) => wrapped.apply(transform);

  @override
  declareOutputs(DeclaringTransform transform) =>
      (wrapped as DeclaringTransformer).declareOutputs(transform);

  @override
  isPrimary(AssetId id) => wrapped.isPrimary(id);
}

class _LazyAggregateTransformerWrapper extends LazyTransformerWrapper
    implements AggregateTransformer, LazyAggregateTransformer {
  AggregateTransformer get wrapped => super.wrapped;
  _LazyAggregateTransformerWrapper(AggregateTransformer wrapped)
      : super._(wrapped) {
    checkState(wrapped is AggregateTransformer);
  }

  @override
  apply(AggregateTransform transform) => wrapped.apply(transform);

  @override
  declareOutputs(DeclaringAggregateTransform transform) =>
      (wrapped as DeclaringAggregateTransformer).declareOutputs(transform);

  @override
  classifyPrimary(AssetId id) => wrapped.classifyPrimary(id);
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

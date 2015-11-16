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
abstract class EagerTransformerWrapper {
  final wrapped;
  EagerTransformerWrapper._(this.wrapped);

  factory EagerTransformerWrapper(wrapped) {
    return wrapped is AggregateTransformer
        ? new _EagerAggregateTransformerWrapper(wrapped)
        : new _EagerTransformerWrapper(wrapped);
  }

  @override
  toString() => wrapped.toString();
}

abstract class _TransformerWrapper implements Transformer {
  Transformer get wrapped;

  String get allowedExtensions => wrapped.allowedExtensions;

  apply(Transform transform) => wrapped.apply(transform);

  declareOutputs(DeclaringTransform transform) =>
      (wrapped as DeclaringTransformer).declareOutputs(transform);

  isPrimary(AssetId id) => wrapped.isPrimary(id);
}

class _EagerTransformerWrapper extends EagerTransformerWrapper
    with _TransformerWrapper
    implements Transformer, LazyTransformer {
  Transformer get wrapped => super.wrapped;
  _EagerTransformerWrapper(Transformer wrapped) : super._(wrapped) {
    checkState(wrapped is Transformer);
  }
}

class _LazyTransformerWrapper extends LazyTransformerWrapper
    with _TransformerWrapper
    implements Transformer, LazyTransformer {
  Transformer get wrapped => super.wrapped;
  _LazyTransformerWrapper(Transformer wrapped) : super._(wrapped) {
    checkState(wrapped is Transformer);
  }
}

abstract class _AggregateTransformerWrapper {
  AggregateTransformer get wrapped;

  apply(AggregateTransform transform) => wrapped.apply(transform);

  declareOutputs(DeclaringAggregateTransform transform) =>
      (wrapped as DeclaringAggregateTransformer).declareOutputs(transform);

  classifyPrimary(AssetId id) => wrapped.classifyPrimary(id);
}

class _EagerAggregateTransformerWrapper extends EagerTransformerWrapper
    with _AggregateTransformerWrapper
    implements AggregateTransformer, LazyAggregateTransformer {
  _EagerAggregateTransformerWrapper(AggregateTransformer wrapped)
      : super._(wrapped) {
    checkState(wrapped is AggregateTransformer);
  }
}

class _LazyAggregateTransformerWrapper extends LazyTransformerWrapper
    with _AggregateTransformerWrapper
    implements AggregateTransformer, LazyAggregateTransformer {
  _LazyAggregateTransformerWrapper(AggregateTransformer wrapped)
      : super._(wrapped) {
    checkState(wrapped is AggregateTransformer);
  }
}

class _TransformerGroupWrapper implements TransformerGroup {
  final TransformerGroup group;
  final Iterable<Iterable> phases;
  _TransformerGroupWrapper(
      TransformerGroup group,
      transformerWrapper(dynamic transformer))
          : this.group = group,
            this.phases = group.phases
                .map((ts) => ts.map(transformerWrapper))
                .toList();

  @override
  toString() => group.toString();
}

class LazyTransformerGroupWrapper extends _TransformerGroupWrapper {
  LazyTransformerGroupWrapper(group)
      : super(group, (t) => new LazyTransformerWrapper(t));
}

class EagerTransformerGroupWrapper extends _TransformerGroupWrapper {
  EagerTransformerGroupWrapper(group)
      : super(group, (t) => new EagerTransformerWrapper(t));
}

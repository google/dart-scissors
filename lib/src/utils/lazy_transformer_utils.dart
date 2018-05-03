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

abstract class BaseWrapper<T> {
  final T wrapped;
  BaseWrapper(this.wrapped);

  @override
  toString() => wrapped.toString();
}

abstract class LazyTransformerWrapper<T> implements BaseWrapper<T> {
  factory LazyTransformerWrapper(T wrapped) {
    return (wrapped is AggregateTransformer
            ? new _LazyAggregateTransformerWrapper(wrapped)
            : new _LazyTransformerWrapper(wrapped as Transformer))
        as LazyTransformerWrapper<T>;
  }
}

abstract class EagerTransformerWrapper<T> implements BaseWrapper<T> {
  factory EagerTransformerWrapper(T wrapped) {
    return (wrapped is AggregateTransformer
            ? new _EagerAggregateTransformerWrapper(wrapped)
            : new _EagerTransformerWrapper(wrapped as Transformer))
        as EagerTransformerWrapper<T>;
  }
}

abstract class _TransformerWrapper<T extends Transformer>
    implements Transformer, BaseWrapper<T> {
  String get allowedExtensions => wrapped.allowedExtensions;

  apply(Transform transform) => wrapped.apply(transform);

  declareOutputs(DeclaringTransform transform) =>
      (wrapped as DeclaringTransformer).declareOutputs(transform);

  isPrimary(AssetId id) => wrapped.isPrimary(id);
}

class _EagerTransformerWrapper<T extends Transformer> extends BaseWrapper<T>
    with EagerTransformerWrapper<T>, _TransformerWrapper<T>
    implements Transformer {
  _EagerTransformerWrapper(Transformer wrapped) : super(wrapped) {
    checkState(wrapped is Transformer);
  }
}

class _LazyTransformerWrapper extends BaseWrapper<Transformer>
    with LazyTransformerWrapper<Transformer>, _TransformerWrapper
    implements Transformer, LazyTransformer {
  _LazyTransformerWrapper(Transformer wrapped) : super(wrapped) {
    checkState(wrapped is Transformer);
  }
}

abstract class _AggregateTransformerWrapper<T extends AggregateTransformer>
    implements BaseWrapper<T> {
  apply(AggregateTransform transform) => wrapped.apply(transform);

  declareOutputs(DeclaringAggregateTransform transform) =>
      (wrapped as DeclaringAggregateTransformer).declareOutputs(transform);

  classifyPrimary(AssetId id) => wrapped.classifyPrimary(id);
}

class _EagerAggregateTransformerWrapper<T extends AggregateTransformer>
    extends BaseWrapper<T>
    with EagerTransformerWrapper<T>, _AggregateTransformerWrapper<T>
    implements AggregateTransformer {
  _EagerAggregateTransformerWrapper(AggregateTransformer wrapped)
      : super(wrapped) {
    checkState(wrapped is AggregateTransformer);
  }
}

class _LazyAggregateTransformerWrapper extends BaseWrapper<AggregateTransformer>
    with
        LazyTransformerWrapper<AggregateTransformer>,
        _AggregateTransformerWrapper
    implements AggregateTransformer, LazyAggregateTransformer {
  _LazyAggregateTransformerWrapper(AggregateTransformer wrapped)
      : super(wrapped) {
    checkState(wrapped is AggregateTransformer);
  }
}

class _TransformerGroupWrapper implements TransformerGroup {
  final TransformerGroup group;
  final Iterable<Iterable> phases;
  _TransformerGroupWrapper(
      TransformerGroup group, transformerWrapper(dynamic transformer))
      : this.group = group,
        this.phases =
            group.phases.map((ts) => ts.map(transformerWrapper)).toList();

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

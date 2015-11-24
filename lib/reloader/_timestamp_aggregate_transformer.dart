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
part of scissors.src.reloader.transformer;

const _timestampAggregate = 'web/timestamp';

class _TimestampAggregateTransformer extends AggregateTransformer
    implements LazyAggregateTransformer {
  @override
  classifyPrimary(AssetId id) =>
      id.extension == _extension ? 'timestamps' : null;

  @override
  apply(AggregateTransform transform) async {
    var maxTimestamp = 0;

    await for (var input in transform.primaryInputs) {
      var timestamp = int.parse(await input.readAsString());
      maxTimestamp = max(timestamp, maxTimestamp);
    }

    transform.logger.info('maxTimestamp = $maxTimestamp');
    transform.addOutput(new Asset.fromString(
        new AssetId(transform.package, _timestampAggregate),
        maxTimestamp.toString()));
  }

  @override
  declareOutputs(DeclaringAggregateTransform transform) {
    transform
        .declareOutput(new AssetId(transform.package, _timestampAggregate));
  }
}

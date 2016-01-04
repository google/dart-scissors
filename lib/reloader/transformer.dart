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
library scissors.src.reloader.transformer;

import 'package:barback/barback.dart';

import 'dart:math';
import '../src/utils/phase_utils.dart';
import '../src/utils/settings_base.dart';

part 'settings.dart';
part '_reloader_removal_transformer.dart';
part '_timestamp_aggregate_transformer.dart';
part '_timestamper_transformer.dart';

/// Auto-reload transformer:
/// - in release (default for pub build), removes mentions / usages of the
///   reloader library without messing sourcemaps up.
/// - in debug (default for pub serve), eagerly timestamps all assets and lazily
///   aggregates the most recent timestamps, so that the reloader library can
///   query `/timestamp` and decide whether to reload the page or not.
class AutoReloadTransformerGroup extends TransformerGroup {
  AutoReloadTransformerGroup.asPlugin(BarbackSettings settings)
      : this(new _ReloaderSettings(settings));
  AutoReloadTransformerGroup(ReloaderSettings settings)
      : super(trimPhases([
          [
            settings.removeReloader.value
                ? new _ReloaderRemovalTransformer()
                : null
          ],
          [
            settings.serveTimestamps.value
                ? new _TimestamperTransformer()
                : null
          ],
          [
            settings.serveTimestamps.value
                ? new _TimestampAggregateTransformer()
                : null
          ]
        ]));
}

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

/// Replaces import and usage of the reloader runtime support script by spaces.
/// This means we don't mess up with the sourcemaps.
class _ReloaderRemovalTransformer extends Transformer
    implements LazyTransformer {
  final RegExp _importRx = new RegExp(
      r'''\bimport\s*['"]package:scissors/reloader/reloader.dart['"]\s*(?:as\s*(\w+)\s*)?;''',
      multiLine: true);
  final RegExp _setupRx = new RegExp(
      r'''\b(?:(\w+)\s*\.\s*)?setupReloader\s*\([^;]*?\)\s*;''',
      multiLine: true);

  @override
  final String allowedExtensions = ".dart";

  @override
  declareOutputs(DeclaringTransform transform) {
    transform.declareOutput(transform.primaryId);
  }

  @override
  apply(Transform transform) async {
    var asset = transform.primaryInput;
    var src = await asset.readAsString();
    var aliases = <String>[];
    src = src.replaceAllMapped(_importRx, (Match m) {
      var s = m.group(0);
      aliases.add(m.group(1));
      return _spaces(s.length);
    });
    if (aliases.isNotEmpty) {
      transform.logger.info('Removing reference to reloader');
      src = src.replaceAllMapped(_setupRx, (Match m) {
        var prefix = m.group(1);
        var s = m.group(0);
        if (aliases.contains(prefix)) {
          return _spaces(s.length);
        } else {
          return s;
        }
      });
      transform.addOutput(new Asset.fromString(asset.id, src));
    }
  }

  @override
  String toString() => 'ReloaderRemoval';
}

String _spaces(int count) {
  var b = new StringBuffer();
  for (int i = 0; i < count; i++) b.write(' ');
  return b.toString();
}

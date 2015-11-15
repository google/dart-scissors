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
library scissors.src.utils.delta_format;

String _formatBytes(int count) => '$count bytes';
String _formatChars(int count) => '$count chars';

String formatDeltaBytes(int from, int to) =>
    _formatDelta(from, to, _formatBytes);

String formatDeltaChars(int from, int to) =>
    _formatDelta(from, to, _formatChars);

String _formatDelta(int from, int to, String unitFormatter(int value)) {
  var delta = to - from;
  var msg = '${unitFormatter(from)} → ${unitFormatter(to)}';
  var sign = delta > 0 ? '+' : '';
  var deltaFmt = '$sign${unitFormatter(delta)}';
  if (from != 0) {
    var percent = ((1000.0 * delta) / from).floor() / 10.0;
    msg = '$msg ($deltaFmt = $sign$percent%)';
  } else {
    msg = '$msg ($deltaFmt)';
  }
  return msg;
}

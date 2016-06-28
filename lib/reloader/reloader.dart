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
library scissors.reloader;

import 'dart:html';
import 'dart:async';

/// Sets up the page reloader: will poll pub serve to know when
/// *any* asset is modified, and will cause the page to be reloaded.
///
/// Note that calls to this function and imports of this file are
/// removed by `scissors/reloader/transformer` in release mode.
Future setupReloader(
    {String timestampBaseUrl: '/',
    Duration delay: const Duration(seconds: 1)}) async {
  var initialTimestamp = await _getTimestamp(timestampBaseUrl);
  await Future.doWhile(() async {
    await new Future.delayed(const Duration(seconds: 1));
    try {
      var timestamp = await _getTimestamp(timestampBaseUrl);
      if (timestamp != initialTimestamp) {
        window.location.reload();
        return false;
      }
    } catch (e) {
      // Do nothing and retry: maybe pub serve went down.
    }
    return true;
  });
}

Future<int> _getTimestamp(String timestampBaseUrl) {
  var completer = new Completer<int>();
  new HttpRequest()
    ..open('GET', timestampBaseUrl + 'timestamp')
    ..onLoad.listen((ProgressEvent event) {
      HttpRequest req = event.target;
      var timestamp = int.parse(req.responseText);
      completer.complete(timestamp);
    })
    ..onError.listen(completer.completeError)
    ..send();
  return completer.future;
}

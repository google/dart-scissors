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
bool setupReloader([delay = const Duration(seconds: 1)]) {
  run() async {
    var initialTimestamp = await _getTimestamp();
    Future.doWhile(() async {
      await new Future.delayed(const Duration(seconds: 1));
      var timestamp = await _getTimestamp();
      if (timestamp != initialTimestamp) {
        window.location.reload();
        return false;
      } else {
        return true;
      }
    });
  }
  run();
  return true;
}


Future<int> _getTimestamp() {
  var completer = new Completer();
  new HttpRequest()
    ..open('GET', '/timestamp')
    ..onLoad.listen((ProgressEvent event) {
      HttpRequest req = event.target;
      var timestamp = int.parse(req.responseText);
      completer.complete(timestamp);
    })
    ..send();
  return completer.future;
}

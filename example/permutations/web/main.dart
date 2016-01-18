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
import 'messages_all.dart';
import 'package:intl/intl.dart';
import 'dart:html';

import 'template_cache_ltr.dart' deferred as tc_ltr;
import 'template_cache_rtl.dart' deferred as tc_rtl;
import 'dart:async';

// TODO(ochafik): add comments
var templateCache;
Future initializeTemplateCache(String locale) async {
  if (Bidi.isRtlLanguage(locale)) {
    await tc_rtl.loadLibrary();
    templateCache = tc_rtl.templateCache;
  } else {
    await tc_ltr.loadLibrary();
    templateCache = tc_ltr.templateCache;
  }
}

main() async {
  var languageRx = new RegExp(r'\bhl=(\w+)\b');
  Intl.defaultLocale = languageRx.firstMatch(window.location.href)?.group(1) ??
      Intl.getCurrentLocale();

  await initializeMessages(Intl.getCurrentLocale());
  await initializeTemplateCache(Intl.getCurrentLocale());

  document.getElementById('message').innerHtml =
      messages['SomeKey'] + '<br/>' + templateCache['some/resource'];
}

import 'messages_all.dart';
import 'package:intl/intl.dart';
import 'dart:html';

import 'template_cache_ltr.dart' deferred as tc_ltr;
import 'template_cache_rtl.dart' deferred as tc_rtl;
import 'dart:async';

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

  print("templateCache: $templateCache");

  document.getElementById('message').innerHtml =
      messages['SomeKey'] + '<br/>' + templateCache['some/resource'];
}

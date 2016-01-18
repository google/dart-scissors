library scissors_mirroring_example.main;

import 'messages_all.dart';
import 'package:angular2/bootstrap.dart';

import 'package:scissors_mirroring_example/foo.dart';
import 'package:intl/intl.dart';
import 'dart:html';

// Loads the [FooComponent] and sets the direction of document according to
// the locale.
main() async {
  var languageRx = new RegExp(r'\bhl=(\w+)\b');
  Intl.defaultLocale = languageRx.firstMatch(window.location.href)?.group(1) ??
      Intl.getCurrentLocale();

  document.querySelector('body').dir =
      Bidi.isRtlLanguage(Intl.getCurrentLocale()) ? 'rtl' : 'ltr';

  await initializeMessages(Intl.getCurrentLocale());

  bootstrap(FooComponent);
}

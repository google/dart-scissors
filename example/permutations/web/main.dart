import 'messages_all.dart';
import 'package:intl/intl.dart';
import 'dart:html';

main() async {
  var languageRx = new RegExp(r'\bhl=(\w+)\b');
  Intl.defaultLocale =
      languageRx.firstMatch(window.location.href)?.group(1)
      ?? Intl.getCurrentLocale();

  await initializeMessages(Intl.getCurrentLocale());

  document.getElementById('message').innerHtml = messages['SomeKey'];
}

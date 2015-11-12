
import 'dart:async';

import 'messages_en.dart' deferred as messages_en;
import 'messages_fr.dart' deferred as messages_fr;

var messages;

Future initializeMessages(String locale) async {
  switch (locale) {
    case 'en':
    case 'en_US':
      await messages_en.loadLibrary();
      messages = messages_en.messages;
      break;
    case 'fr':
      await messages_fr.loadLibrary();
      messages = messages_fr.messages;
      break;
    default:
      throw new ArgumentError('Unknown locale: $locale');
  }
}

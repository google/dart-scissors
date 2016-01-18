library scissors.example.mirroring.messages_all;

import 'dart:async';

import 'messages_ar.dart' deferred as messages_ar;
import 'messages_en.dart' deferred as messages_en;
import 'messages_fr.dart' deferred as messages_fr;

// TODO(ochafik): Switch examples to a real package:intl translation
Map<String, String> messages = <String, String>{};

/// Initialises message depending upon the language.
/// Future contains argument error in case of unknown locale.
Future initializeMessages(String locale) async {
  switch (locale) {
    case 'ar':
      await messages_ar.loadLibrary();
      messages = messages_ar.messages;
      break;
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

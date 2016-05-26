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
library scissors.src.permutations.intl_deferred_map;

import 'deferred_map.dart';
import 'package:quiver/check.dart';
import 'package:intl/intl.dart';

class IntlDeferredMap {
  final DeferredMap _map;
  final mainNames = new Set<String>();
  final locales = new Set<String>();
  IntlDeferredMap(this._map) {
    mainNames.addAll(_map.collectParts().map(_getMainName));
    _map.visitImports((entry, imports) {
      if (imports.alias.startsWith("messages_")) {
        locales.add(imports.alias.substring("messages_".length));
      }
    }, entryPredicate: _isMessagesAllEntry);
  }

  factory IntlDeferredMap.fromJson(String json) =>
      new IntlDeferredMap(new DeferredMap.fromJson(json));

  List<String> _getDirectionSpecificImports(String importAlias) {
    if (importAlias == null) return <String>[];

    var res = _map.collectParts(
        importsPredicate: (imports) => imports.alias == importAlias);
    checkState(res.isNotEmpty,
        message: () =>
            "Failed to find any deferred import with alias $importAlias");
    return res;
  }

  bool _isMessagesAllEntry(DeferredMapEntry entry) =>
      entry.key.endsWith("messages_all.dart") || entry.name == "messages_all";

  static final RegExp _partRx = new RegExp(r'^(.*?)\.dart\.js_\d+\.part\.js$');

  String _getMainName(String part) {
    Match m = checkNotNull(_partRx.firstMatch(part),
        message: () => '$part does not look like a part path');
    return m[1];
  }

  List<String> _getMessagePartsForLocale(locale) => _map.collectParts(
      importsPredicate: (imports) => imports.alias == 'messages_$locale',
      entryPredicate: _isMessagesAllEntry);

  List<String> getPartsForLocale(
          {String locale, String ltrImportAlias, String rtlImportAlias}) =>
      <String>[]
        ..addAll(_getMessagePartsForLocale(locale))
        ..addAll(Bidi.isRtlLanguage(locale)
            ? _getDirectionSpecificImports(rtlImportAlias)
            : _getDirectionSpecificImports(ltrImportAlias));

  List<String> getImportAliasesForPart(String targetPart) {
    var aliases = new Set<String>();
    _map.visitParts((entry, imports, part) {
      if (part == targetPart) aliases.add(imports.alias);
    });
    return aliases.toList();
  }
}

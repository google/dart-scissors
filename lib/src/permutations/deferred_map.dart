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
library scissors.src.permutations.deferred_map;

import 'dart:convert';
import 'dart:collection';

class DeferredMapImports {
  final String alias;
  final List<String> parts;
  DeferredMapImports(this.alias, this.parts);

  toString() => 'Imports($alias, $parts)';
}

class DeferredMapEntry {
  final String key;
  final String name;
  final List<DeferredMapImports> imports;
  DeferredMapEntry(this.key, this.name, this.imports);

  toString() => 'Entry($name, $imports)';
}

class DeferredMap {
  final String comment;
  final List<DeferredMapEntry> entries;
  DeferredMap(this.comment, this.entries);

  toString() => 'Map($comment, $entries)';

  factory DeferredMap.fromJson(String json) {
    Map data = jsonDecode(json);

    String comment = data['_comment'];
    var entries = <DeferredMapEntry>[];
    data.forEach((k, v) {
      if (v is Map) {
        String name = v['name'];
        var importsValue = v['imports'].map(
            (k, v) => new MapEntry<String, List<String>>(k, v.cast<String>()));
        if (importsValue != null) {
          var imports = <DeferredMapImports>[];
          importsValue.forEach((alias, parts) {
            imports.add(new DeferredMapImports(alias, parts));
          });
          entries.add(new DeferredMapEntry(k, name, imports));
        }
      }
    });
    return new DeferredMap(comment, entries);
  }

  List<String> getAllParts() => collectParts();

  List<String> collectParts(
      {bool entryPredicate(DeferredMapEntry name),
      bool importsPredicate(DeferredMapImports imports)}) {
    var parts = new LinkedHashSet<String>();
    visitParts((entry, imports, part) => parts.add(part),
        entryPredicate: entryPredicate, importsPredicate: importsPredicate);
    return []..addAll(parts);
  }

  void visitImports(
      callback(DeferredMapEntry entry, DeferredMapImports imports),
      {bool entryPredicate(DeferredMapEntry entry)}) {
    for (var entry in entries) {
      if (entryPredicate == null || entryPredicate(entry)) {
        for (var imports in entry.imports) {
          callback(entry, imports);
        }
      }
    }
  }

  void visitParts(
      callback(DeferredMapEntry entry, DeferredMapImports imports, String part),
      {bool entryPredicate(DeferredMapEntry name),
      bool importsPredicate(DeferredMapImports imports)}) {
    visitImports((entry, imports) {
      if (importsPredicate == null || importsPredicate(imports)) {
        for (String part in imports.parts) {
          callback(entry, imports, part);
        }
      }
    }, entryPredicate: entryPredicate);
  }
}

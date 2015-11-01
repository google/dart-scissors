library scissors.src.enum_parser;

import 'package:quiver/check.dart';

String enumName(dynamic value) {
  var split = value.toString().split('.');
  checkArgument(split.length == 2,
      message: () => "Unrecognized enum name: $value");
  return split[1];
}

class EnumParser<E> {
  Map<String, E> _byName;
  EnumParser._(this._byName);
  factory EnumParser(List<E> values) =>
      new EnumParser._(new Map.fromIterable(values, key: enumName));

  E parse(String name) {
    var value = _byName[name];
    if (value == null) {
      throw new ArgumentError(
        'Invalid value $name '
        '(expected one of ${_byName.keys.join(', ')}');
    }
    return value;
  }
}

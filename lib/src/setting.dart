part of scissors.src.settings;

class _Setting<T> {
  final String key;
  final String comment;
  final T debugDefault;
  final T releaseDefault;
  final Function parser;
  bool _read = false;
  T _value;
  T get value {
    checkState(_read);
    return _value;
  }

  _Setting(this.key,
      {this.comment, T defaultValue, T debugDefault, T releaseDefault,
       T this.parser(String s)})
      : this.debugDefault = debugDefault ?? defaultValue,
        this.releaseDefault = releaseDefault ?? defaultValue;

  read(Map config, bool isDebug) {
    checkState(!_read);
    _read = true;
    var value = config[key];
    if (value == null) {
      _value = isDebug ? debugDefault : releaseDefault;
    } else {
      _value = parser != null ? parser(value) : value;
    }
    // print("VALUE[$key] = $_value (${config[key]})");
  }
}

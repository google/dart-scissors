part of scissors.src.settings;

class _Setting<T> {
  final String key;
  final String comment;
  final T debugDefault;
  final T releaseDefault;
  bool _read = false;
  T _value;
  T get value {
    checkState(_read);
    return _value;
  }

  _Setting(this.key,
      {this.comment, T defaultValue, T debugDefault, T releaseDefault})
      : this.debugDefault = debugDefault ?? defaultValue,
        this.releaseDefault = releaseDefault ?? defaultValue;

  read(Map config, bool isDebug) {
    checkState(!_read);
    _read = true;
    _value = config[key] ?? (isDebug ? debugDefault : releaseDefault);
  }
}

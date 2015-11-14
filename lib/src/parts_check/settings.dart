part of scissors.src.parts_check.transformer;

abstract class PartsCheckSettings {
  final expectedPartCounts =
      new Setting<Map>('expectedPartCounts', defaultValue: {});
}

class _PartsCheckSettings extends SettingsBase with PartsCheckSettings {
  _PartsCheckSettings.fromSettings(settings): super.fromSettings(settings);
}

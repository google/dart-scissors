part of scissors.src.permutations.transformer;

abstract class PermutationsSettings {
  final expectedPartCounts =
      new Setting<Map>('expectedPartCounts', defaultValue: {});

  final ltrImport = new Setting<String>('ltrImport');
  final rtlImport = new Setting<String>('rtlImport');

  final generatePermutations =
      makeBoolSetting('generatePermutations');

  final reoptimizePermutations =
      makeOptimSetting('reoptimizePermutations', false);

  final javaPath = makePathSetting('javaPath', pathResolver.defaultJavaPath);

  final closureCompilerJarPath = makePathSetting(
      'closureCompilerJar', pathResolver.defaultClosureCompilerJarPath);
}

// class _PermutationsSettings extends SettingsBase with PermutationsSettings {
//   _PermutationsSettings.fromSettings(settings): super.fromSettings(settings);
// }

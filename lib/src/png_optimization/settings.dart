part of scissors.src.png_optimization.transformer;

class PngOptimizationSettings {
  final optimizePng = makeOptimSetting('optimizePng');

  final pngCrushPath =
      makePathSetting('pngCrushPath', pathResolver.defaultPngCrushPath);
}

class _PngOptimizationSettings extends SettingsBase with PngOptimizationSettings {
  _PngOptimizationSettings.fromSettings(settings) : super.fromSettings(settings);
}

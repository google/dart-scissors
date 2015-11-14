part of scissors.src.image_inlining.transformer;

abstract class ImageInliningSettings {

  final imageInlining = new Setting<ImageInliningMode>(
      'imageInlining',
      debugDefault: ImageInliningMode.linkInlinedImages,
      releaseDefault: ImageInliningMode.inlineInlinedImages,
      parser:
          new EnumParser<ImageInliningMode>(ImageInliningMode.values).parse);

  final packageRewrites = new Setting<String>(
      'packageRewrites', defaultValue: "^package:,packages/");

  final javaPath =
      makePathSetting('javaPath', pathResolver.defaultJavaPath);

  final closureCompilerJarPath =
      makePathSetting('closureCompilerJar', pathResolver.defaultClosureCompilerJarPath);
}

class _ImageInliningSettings extends SettingsBase with ImageInliningSettings {
  _ImageInliningSettings.fromSettings(settings)
      : super.fromSettings(settings);
}

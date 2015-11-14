part of scissors.src.css_pruning.transformer;

class CssPruningSettings {

  final pruneCss = new Setting<bool>('pruneCss', defaultValue: true);

  // final mirrorCss = new Setting<bool>('mirrorCss',
  //     comment:
  //         "Whether to perform LTR -> RTL mirroring of .css files with cssjanus.",
  //     defaultValue: false);
}

class _CssPruningSettings extends SettingsBase with CssPruningSettings {
  _CssPruningSettings.fromSettings(settings)
      : super.fromSettings(settings);
}

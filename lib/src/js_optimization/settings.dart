library scissors.src.image_optimization.settings;

import '../utils/settings_base.dart';
import '../utils/path_resolver.dart';

class JsOptimizationSettings {

  final reoptimizePermutations =
      makeOptimSetting('reoptimizePermutations', false);

  final javaPath = makePathSetting('javaPath', pathResolver.defaultJavaPath);

  final closureCompilerJarPath = makePathSetting(
      'closureCompilerJar', pathResolver.defaultClosureCompilerJarPath);
}

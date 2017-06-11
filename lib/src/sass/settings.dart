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
part of scissors.src.sass.transformer;

abstract class SassSettings {
  bool get isDebug;

  final compileSass = new Setting<bool>('compileSass', defaultValue: true);

  final onlyCompileOutOfDateSass =
      new Setting<bool>('onlyCompileOutOfDateSass', defaultValue: false);

  final imageInlining = new Setting<ImageInliningMode>('imageInlining',
      defaultValue: ImageInliningMode.inlineInlinedImages,
      parser:
          new EnumParser<ImageInliningMode>(ImageInliningMode.values).parse);

  final packageRewrites = new Setting<String>('packageRewrites',
      defaultValue: "^package:,packages/");

  final compassStylesheetsPath = makePathSetting(
      'compassStylesheetsPath', pathResolver.defaultCompassStylesheetsPath);

  final sasscPath = makePathSetting('sasscPath', pathResolver.defaultSassCPath,
      isExecutable: true);

  final sasscArgs = new Setting<List<String>>('sasscArgs', defaultValue: []);
  final compiledCssExtensionMode = new Setting<ExtensionMode>(
      'compiledCssExtension',
      defaultValue: pathResolver.defaultCompiledCssExtensionMode,
      parser: parseExtensionMode);

  Future<SasscSettings> _sasscSettings;
  Future<SasscSettings> get sasscSettings {
    if (_sasscSettings == null) {
      _sasscSettings = (() async {
        var sasscIncludes = <Directory>[];
        var args = <String>[]..addAll(await _resolveSassIncludePaths(
              sasscArgs.value.map(resolveEnvVars).toList(),
              (String includePath) async {
            includePath = absolute(await pathResolver.resolvePath(includePath));
            sasscIncludes.add(new Directory(includePath));
            return includePath;
          }));

        for (var dir in await pathResolver.getSassIncludeDirectories()) {
          args..add("--load-path")..add(dir.path);
          sasscIncludes.add(dir);
        }
        return new SasscSettings(await sasscPath.value, args, sasscIncludes,
            compiledCssExtensionMode.value);
      })();
    }
    return _sasscSettings;
  }
}

const _loadPathPrefixes = const <String>['-I', '--load-path='];

Future<List<String>> _resolveSassIncludePaths(
    List<String> args, Future<String> transform(String path)) async {
  args = new List<String>.from(args);

  for (int i = 0, n = args.length; i < n; i++) {
    var arg = args[i];
    if (arg == '-I' || arg == '--load-path') {
      i++;
      args[i] = await transform(args[i]);
    } else {
      for (var prefix in _loadPathPrefixes) {
        if (arg.startsWith(prefix)) {
          args[i] = prefix + await transform(arg.substring(prefix.length));
          break;
        }
      }
    }
  }
  return args;
}

class _SassSettings extends SettingsBase with SassSettings {
  _SassSettings(settings) : super(settings);
}

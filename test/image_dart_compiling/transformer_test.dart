import 'package:transformer_test/utils.dart';
import 'package:scissors/image_dart_transformer.dart';

main() {
  var iconSvg = r'''
    <?xml version="1.0" encoding="utf-8"?>
    <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
      <rect x="0" y="0" height="10" width="10" style="stroke:#00ff00; fill: #ff0000"/>
    </svg>
  ''';
  var iconSvgData =
      'ICAgIDw/eG1sIHZlcnNpb249IjEuMCIgZW5jb2Rpbmc9InV0Zi04Ij8+CiAgICA8c3ZnIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiPgogICAgICA8cmVjdCB4PSIwIiB5PSIwIiBoZWlnaHQ9IjEwIiB3aWR0aD0iMTAiIHN0eWxlPSJzdHJva2U6IzAwZmYwMDsgZmlsbDogI2ZmMDAwMCIvPgogICAgPC9zdmc+CiAg';

  List<List> phases = [
    [new DartImageCompiler.asPlugin()]
  ];
  testPhases('image_dart_transformer generates images.dart file', phases, {
    'web|icon.svg': iconSvg
  }, {
    'web|images.dart':
        'const icon = "data:image/svg+xml;base64,$iconSvgData";\n'
  });
}

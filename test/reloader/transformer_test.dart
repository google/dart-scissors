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
library scissors.test.reloader.transformer_test;

import 'package:barback/barback.dart' show BarbackMode, BarbackSettings;

import 'package:scissors/reloader/transformer.dart';
import 'package:scissors/src/utils/lazy_transformer_utils.dart';
import 'package:transformer_test/utils.dart' show testPhases;

List<List> makePhases(BarbackMode mode) => new EagerTransformerGroupWrapper(
        new AutoReloadTransformerGroup.asPlugin(new BarbackSettings({}, mode)))
    .phases
    .map((phase) => phase.toList())
    .toList();

void main() {
  testPhases('removes mentions of the reloader lib in release mode',
      makePhases(BarbackMode.RELEASE), {
    'a|foo.dart': '''
      /**/import 'package:scissors/reloader/reloader.dart';/**/
      /**/import  'package:scissors/reloader/reloader.dart'  as  foo;/**/
      import 'package:some/other.dart' as foo;
      main() {
        /**/foo.setupReloader();/**/
        /**/setupReloader(const Duration(seconds: 3));/**/
      }
    '''
  }, {
    'a|foo.dart': '''
      /**/                                                 /**/
      /**/                                                           /**/
      import 'package:some/other.dart' as foo;
      main() {
        /**/                    /**/
        /**/                                          /**/
      }
    '''
  });

  var src = '''
    import 'package:scissors/reloader/reloader.dart';
    main() {
      setupReloader();
    }
  ''';
  testPhases('leaves reloader alone in debug mode',
      makePhases(BarbackMode.DEBUG), {'a|foo.dart': src}, {'a|foo.dart': src});
}

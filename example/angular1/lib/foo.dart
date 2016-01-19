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
library scissors_angular1_example.foo;

import 'package:angular/angular.dart';

@Component(
    selector: 'foo',
    template: '''
      <present-element>Hello!</present-element>
      <div class="used-class">World!</div>
      <div class="plus-image">...plus...</div>
    ''',
    cssUrl: 'package:scissors_angular1_example/foo.css')
class FooComponent {}

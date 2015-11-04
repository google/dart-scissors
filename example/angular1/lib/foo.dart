library scissors_angular1_example.foo;

import 'package:angular/angular.dart';

@Component(
    selector: 'foo',
    template: '''
      <present-element>Hello!</present-element>
      <div class="used-class">World!</div>
      <div class="plus-image">...plus...</div>
    ''',
    cssUrl: 'package:scissors_angular1_example/foo.scss.css')
class FooComponent {}

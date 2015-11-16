library scissors_angular1_example.foo;

import 'package:angular/angular.dart';

@Component(
    selector: 'sidebar',
    template: '''
      <div class="menu">
        <content></content>
      </div>
      <div class="content">
        <content></content>
      </div>
    ''',
    cssUrl: 'package:scissors_angular1_example/foo.scss.css')
class SidebarComponent {}

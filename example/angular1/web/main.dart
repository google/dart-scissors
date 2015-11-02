import 'package:angular/angular.dart';
import 'package:angular/application_factory.dart';
import 'package:di/di.dart' show Module;

import 'package:scissors_angular1_example/foo.dart';

class MyModule extends Module {
  MyModule() {
    bind(FooComponent);
  }
}

main() {
  var app = applicationFactory().addModule(new MyModule()).run();
}

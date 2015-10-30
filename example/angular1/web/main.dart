import 'package:angular/angular.dart';
import 'package:angular/application_factory.dart';

import 'package:scissors_angular1_example/foo.dart';

main() {
  applicationFactory().addModule(new Module()..bind(FooComponent)).run();
}

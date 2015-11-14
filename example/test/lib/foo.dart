import 'dart:mirrors';

class Bar {
  Bar() {
    InstanceMirror m = reflect(this);
    m.type.instanceMembers.forEach((Symbol name, MethodMirror mm) {
      // mm.
    });
    // print(m.type.members);
  }
}

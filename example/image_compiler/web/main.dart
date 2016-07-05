import 'dart:html';
import 'pics/images.dart' as pics;

void main() {
  (querySelector('#inlined_image') as ImageElement).src = pics.icon;
}

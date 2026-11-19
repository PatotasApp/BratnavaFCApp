import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final src = img.decodePng(File('assets/images/logo.png').readAsBytesSync())!;
  print('logo.png: ${src.width}x${src.height}');
  final icon =
      img.decodePng(File('assets/images/logo_icon.png').readAsBytesSync())!;
  print('logo_icon.png: ${icon.width}x${icon.height}');
}

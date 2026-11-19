// Gera logo_splash.png com padding generoso para o splash screen.
// O flutter_native_splash centraliza a imagem — se ela for grande demais corta as bordas.
// Execute: dart run scripts/pad_splash.dart

import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final src = img.decodePng(File('assets/images/logo.png').readAsBytesSync())!;

  const outputSize = 1024;

  // Logo ocupa apenas 45% → padding de 27.5% em cada lado
  // Garante que as estrelas fiquem bem dentro da área visível
  final logoSize = (outputSize * 0.45).round();
  final offset = ((outputSize - logoSize) / 2).round();

  final canvas = img.Image(width: outputSize, height: outputSize);
  img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));

  final resized = img.copyResize(src,
      width: logoSize,
      height: logoSize,
      interpolation: img.Interpolation.average);

  img.compositeImage(canvas, resized, dstX: offset, dstY: offset);

  File('assets/images/logo_splash.png').writeAsBytesSync(img.encodePng(canvas));
  print('✅ logo_splash.png gerado em assets/images/');
}

// Gera uma versão do logo com padding para caber no safe zone do adaptive icon.
// O safe zone é 66% do centro — então colocamos o logo em ~60% e padding nos outros 40%.
// Execute com: dart run scripts/pad_icon.dart

import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final src = img.decodePng(File('assets/images/logo.png').readAsBytesSync())!;

  // Tamanho final: 1024x1024 (flutter_launcher_icons redimensiona depois)
  const outputSize = 1024;

  // O logo vai ocupar 75% do centro
  final logoSize = (outputSize * 0.75).round();
  final offset = ((outputSize - logoSize) / 2).round();

  // Canvas branco — garante fundo branco tanto no ícone adaptativo quanto no legado
  final canvas = img.Image(width: outputSize, height: outputSize);
  img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));

  // Redimensiona o logo mantendo proporção
  final resized = img.copyResize(src, width: logoSize, height: logoSize);

  // Cola o logo centralizado
  img.compositeImage(canvas, resized, dstX: offset, dstY: offset);

  // Salva
  File('assets/images/logo_icon.png').writeAsBytesSync(img.encodePng(canvas));
  print('✅ logo_icon.png gerado em assets/images/');
}

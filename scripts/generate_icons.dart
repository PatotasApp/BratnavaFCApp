/// Gera todos os assets de ícone a partir de logo.png.
///
/// Saídas:
///   assets/images/logo_hires.png      — 1024x1024, fundo transparente (adaptive foreground)
///   assets/images/logo_icon.png       — 1024x1024, fundo branco (legacy icon)
///
/// Execute com: dart run scripts/generate_icons.dart

import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final srcBytes = File('assets/images/logo.png').readAsBytesSync();
  final src = img.decodePng(srcBytes)!;

  print('Fonte: ${src.width}x${src.height}px');

  const targetSize = 1024;

  // ── 1. logo_hires.png ────────────────────────────────────────────────────
  // Upscala com interpolação cúbica para preservar ao máximo as bordas e cores.
  // Fundo transparente — o adaptive_icon_background fornece o branco no Android.
  final hires = img.copyResize(
    src,
    width: targetSize,
    height: targetSize,
    interpolation: img.Interpolation.cubic,
    maintainAspect: true,
  );

  File('assets/images/logo_hires.png').writeAsBytesSync(img.encodePng(hires));
  print('✅ logo_hires.png  — ${hires.width}x${hires.height}px (transparent)');

  // ── 2. logo_icon.png ─────────────────────────────────────────────────────
  // Versão com fundo branco para o ícone legado (Android < 26 / iOS).
  // Logo ocupa 80% do canvas para caber com margem e boa legibilidade.
  const logoRatio = 0.80;
  final logoSize = (targetSize * logoRatio).round();
  final offset = ((targetSize - logoSize) / 2).round();

  final logoResized = img.copyResize(
    src,
    width: logoSize,
    height: logoSize,
    interpolation: img.Interpolation.cubic,
    maintainAspect: true,
  );

  final canvas = img.Image(width: targetSize, height: targetSize);
  img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));
  img.compositeImage(canvas, logoResized, dstX: offset, dstY: offset);

  File('assets/images/logo_icon.png').writeAsBytesSync(img.encodePng(canvas));
  print(
      '✅ logo_icon.png   — ${canvas.width}x${canvas.height}px (white bg, logo 80%)');
}

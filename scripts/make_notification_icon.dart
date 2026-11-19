// Gera ic_notification.png: logo branco em fundo transparente
// para uso como ícone de notificação Android.
// Execute: dart run scripts/make_notification_icon.dart

import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final src = img.decodePng(File('assets/images/logo.png').readAsBytesSync())!;

  // Converte para RGBA caso seja RGB
  final rgba = src.convert(numChannels: 4);

  // Para cada pixel: se for fundo branco/quase-branco → transparente
  // caso contrário → branco opaco (Android usa só o alpha para colorir)
  for (final pixel in rgba) {
    final r = pixel.r.toInt();
    final g = pixel.g.toInt();
    final b = pixel.b.toInt();

    // Limiar: pixel "branco" = todos os canais > 240
    if (r > 240 && g > 240 && b > 240) {
      pixel.a = 0; // transparente
    } else {
      pixel
        ..r = 255
        ..g = 255
        ..b = 255
        ..a = 255; // branco opaco
    }
  }

  // Salva nos tamanhos necessários para cada densidade Android
  final densities = {
    'mdpi': 24,
    'hdpi': 36,
    'xhdpi': 48,
    'xxhdpi': 72,
    'xxxhdpi': 96,
  };

  for (final entry in densities.entries) {
    final dir = Directory('android/app/src/main/res/drawable-${entry.key}');
    dir.createSync(recursive: true);

    final resized = img.copyResize(rgba,
        width: entry.value,
        height: entry.value,
        interpolation: img.Interpolation.average);

    File('${dir.path}/ic_notification.png')
        .writeAsBytesSync(img.encodePng(resized));
  }

  // Também no drawable genérico (fallback)
  Directory('android/app/src/main/res/drawable').createSync(recursive: true);
  final res48 = img.copyResize(rgba, width: 48, height: 48);
  File('android/app/src/main/res/drawable/ic_notification.png')
      .writeAsBytesSync(img.encodePng(res48));

  print('✅ ic_notification.png gerado em todos os tamanhos!');
}

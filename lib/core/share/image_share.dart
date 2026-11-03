import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Compartilhar uma imagem gerada no app: Story do Instagram, copiar imagem e
/// o menu do sistema. Story e copiar são nativos (MainActivity.kt e
/// AppDelegate.swift, canal `br.com.patotasapp/image_share`), com o PNG
/// gravado em `cache/share/` (pasta liberada no FileProvider do Android).
class ImageShare {
  ImageShare._();

  static const _channel = MethodChannel('br.com.patotasapp/image_share');

  /// Captura o widget sob [key] (um RepaintBoundary) como PNG.
  /// [pixelRatio] multiplica o tamanho lógico (ex.: 360 × 3 = 1080 px).
  static Future<Uint8List> capture(GlobalKey key,
      {double pixelRatio = 3}) async {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw StateError('Imagem ainda não montada.');
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) throw StateError('Falha ao gerar a imagem.');
    return data.buffer.asUint8List();
  }

  static Future<File> _save(Uint8List png, String name) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/share');
    await dir.create(recursive: true);
    final file = File('${dir.path}/$name.png');
    await file.writeAsBytes(png, flush: true);
    return file;
  }

  /// Abre o Instagram direto no story. false = Instagram não instalado (ou
  /// plataforma sem suporte): quem chama decide o plano B.
  static Future<bool> shareToInstagramStory(Uint8List png,
      {String name = 'patotasapp'}) async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    final file = await _save(png, name);
    try {
      return await _channel
              .invokeMethod<bool>('instagramStory', {'path': file.path}) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Copia a imagem para a área de transferência. false = não deu.
  static Future<bool> copyImage(Uint8List png,
      {String name = 'patotasapp'}) async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    final file = await _save(png, name);
    try {
      return await _channel
              .invokeMethod<bool>('copyImage', {'path': file.path}) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Menu de compartilhar do sistema (WhatsApp, Instagram, salvar...).
  static Future<void> shareSystem(Uint8List png,
      {String name = 'patotasapp', String? text}) async {
    final file = await _save(png, name);
    await Share.shareXFiles([XFile(file.path, mimeType: 'image/png')],
        text: text);
  }
}

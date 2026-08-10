import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import 'prototype_ui.dart';

/// Avatar do protótipo (`.proto-avatar`).
///
/// Quadrado arredondado com fundo `--accent-bg` e iniciais em `--accent-text`.
/// A versão anterior usava círculo com gradiente por nome — bonito, mas
/// divergia do protótipo em toda lista do app.
///
/// Para voltar ao gradiente pontualmente, use [AvatarWidget.gradient].
class AvatarWidget extends StatelessWidget {
  final String name;
  final double size;
  final String? photoUrl;
  final BoxFit fit;

  /// Mantém o visual antigo (círculo + gradiente). Usado onde o gradiente é
  /// intencional, como nos cards de destaque do God Mode.
  final bool gradient;

  const AvatarWidget({
    super.key,
    required this.name,
    this.size = PrototypeLayout.avatarSize,
    this.photoUrl,
    this.fit = BoxFit.cover,
    this.gradient = false,
  });

  const AvatarWidget.gradient({
    super.key,
    required this.name,
    this.size = PrototypeLayout.avatarSize,
    this.photoUrl,
    this.fit = BoxFit.cover,
  }) : gradient = true;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initials = _initials(name);
    final resolvedPhotoUrl = _resolvePhotoUrl(photoUrl);

    if (resolvedPhotoUrl != null) {
      final radius = gradient
          ? size / 2
          : (size * (PrototypeLayout.avatarRadius / PrototypeLayout.avatarSize))
              .clamp(8.0, 18.0);
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          resolvedPhotoUrl,
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (_, __, ___) => _InitialsAvatar(
            name: name,
            size: size,
            gradient: gradient,
          ),
        ),
      );
    }

    if (gradient) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.primaryContainer,
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: TextStyle(
            color: colors.onPrimaryContainer,
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    // Proporções do protótipo: 34px de lado, raio 12, fonte 11, peso 800.
    // O raio acompanha o tamanho para o avatar não ficar quadrado demais quando
    // usado grande (46) nem redondo demais quando pequeno (24).
    final radius =
        (size * (PrototypeLayout.avatarRadius / PrototypeLayout.avatarSize))
            .clamp(8.0, 18.0);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: colors.onPrimaryContainer,
          fontSize: size * 0.32,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  static String? _resolvePhotoUrl(String? value) {
    final url = value?.trim();
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '${AppConstants.apiUrl}${url.startsWith('/') ? url : '/$url'}';
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;
  final bool gradient;

  const _InitialsAvatar(
      {required this.name, required this.size, required this.gradient});

  @override
  Widget build(BuildContext context) => AvatarWidget(
        name: name,
        size: size,
        gradient: gradient,
      );
}

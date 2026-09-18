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
  final double? borderRadius;

  /// Mantém o visual antigo (círculo + gradiente). Usado onde o gradiente é
  /// intencional, como nos cards de destaque do God Mode.
  final bool gradient;

  const AvatarWidget({
    super.key,
    required this.name,
    this.size = PrototypeLayout.avatarSize,
    this.photoUrl,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.gradient = false,
  });

  const AvatarWidget.gradient({
    super.key,
    required this.name,
    this.size = PrototypeLayout.avatarSize,
    this.photoUrl,
    this.fit = BoxFit.cover,
    this.borderRadius,
  }) : gradient = true;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initials = _initials(name);
    final resolvedPhotoUrl = _resolvePhotoUrl(photoUrl);

    if (resolvedPhotoUrl != null) {
      final radius = gradient ? size / 2 : _resolvedRadius(size, borderRadius);
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
            borderRadius: borderRadius,
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

    // O raio acompanha o tamanho, mantendo o avatar como um quadrado
    // suavemente arredondado em listas pequenas e médias.
    final radius = _resolvedRadius(size, borderRadius);

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

  static double _resolvedRadius(double size, double? requestedRadius) {
    if (requestedRadius != null && requestedRadius > 0) {
      return requestedRadius;
    }
    // Avatares de lista lembram um quadrado suavemente arredondado, sem se
    // aproximar do formato circular. Raios explícitos de perfil e logo
    // continuam sendo respeitados.
    return (size * 0.24).clamp(6.0, 12.0);
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;
  final bool gradient;
  final double? borderRadius;

  const _InitialsAvatar({
    required this.name,
    required this.size,
    required this.gradient,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) => AvatarWidget(
        name: name,
        size: size,
        gradient: gradient,
        borderRadius: borderRadius,
      );
}

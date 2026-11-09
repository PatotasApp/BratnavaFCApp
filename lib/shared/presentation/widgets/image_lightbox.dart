import 'package:flutter/material.dart';

Future<void> showImageLightbox(
  BuildContext context, {
  required String imageUrl,
  required String heroTag,
}) {
  final colors = Theme.of(context).colorScheme;
  return showDialog<void>(
    context: context,
    barrierColor: colors.scrim.withValues(alpha: .92),
    builder: (_) => Dialog.fullscreen(
      backgroundColor: colors.surface.withValues(alpha: 0),
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: .8,
              maxScale: 4,
              child: Hero(
                tag: heroTag,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.broken_image_outlined,
                    color: colors.onInverseSurface,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: SafeArea(
              child: IconButton.filledTonal(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Fechar',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

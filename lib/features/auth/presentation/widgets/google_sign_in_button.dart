import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Botão de entrar com o Google.
///
/// O glifo é desenhado aqui porque o projeto não tem o "G" oficial em asset e
/// não depende de `flutter_svg`. As diretrizes do Google pedem o logotipo nas
/// cores originais — antes de publicar, troque o [_GoogleGlyph] pelo PNG/SVG
/// oficial em `assets/images/`.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.onDark,
          side: const BorderSide(color: AppColors.lightBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GoogleGlyph(),
            SizedBox(width: 12),
            Text(
              'Entrar com Google',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.lightText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1,
            color: AppColors.googleBlue,
          ),
        ),
      ),
    );
  }
}

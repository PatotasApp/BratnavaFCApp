import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';

/// Botão de entrar com a Apple.
///
/// Segue as diretrizes da Apple para o estilo preto: fundo preto, logo e texto
/// brancos, mesma altura e destaque do botão do Google. A tela de login força o
/// tema claro, então a variante preta é a correta aqui.
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.appleBlack,
          foregroundColor: AppColors.onDark,
          disabledBackgroundColor: AppColors.appleBlack.withValues(alpha: 0.5),
          disabledForegroundColor: AppColors.onDark70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/images/apple_logo.svg',
              width: 18,
              height: 18,
              colorFilter:
                  const ColorFilter.mode(AppColors.onDark, BlendMode.srcIn),
              // O rótulo ao lado já anuncia a ação.
              excludeFromSemantics: true,
            ),
            const SizedBox(width: 8),
            const Text(
              'Apple',
              semanticsLabel: 'Entrar com Apple',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

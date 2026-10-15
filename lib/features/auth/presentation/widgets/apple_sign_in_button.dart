import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';

/// Botão de entrar com a Apple.
///
/// Estilo "white outline" das diretrizes da Apple: fundo branco, contorno e
/// logo preto. Mesmas medidas e borda do botão do Google, para os dois lerem
/// como um par na tela de login.
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({super.key, required this.onPressed});

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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/images/apple_logo.svg',
              width: 18,
              height: 18,
              colorFilter:
                  const ColorFilter.mode(AppColors.appleBlack, BlendMode.srcIn),
              // O rótulo ao lado já anuncia a ação.
              excludeFromSemantics: true,
            ),
            const SizedBox(width: 8),
            const Text(
              'Apple',
              semanticsLabel: 'Entrar com Apple',
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

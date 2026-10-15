import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import 'auth_option_button.dart';

/// Botão "Continuar com Apple".
///
/// Estilo "white outline" das diretrizes da Apple: fundo branco, contorno e
/// logo preto, com o mesmo formato das demais opções de login.
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AuthOptionButton(
      onPressed: onPressed,
      label: 'Continuar com Apple',
      icon: SvgPicture.asset(
        'assets/images/apple_logo.svg',
        width: 18,
        height: 18,
        colorFilter:
            const ColorFilter.mode(AppColors.appleBlack, BlendMode.srcIn),
        // O rótulo ao lado já anuncia a ação.
        excludeFromSemantics: true,
      ),
    );
  }
}

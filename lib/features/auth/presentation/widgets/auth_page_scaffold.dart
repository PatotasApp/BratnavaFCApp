import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// Moldura comum das telas de login: tema claro forçado, barra de status
/// escura, logo no topo e o conteúdo logo abaixo, com rodapé opcional.
class AuthPageScaffold extends StatelessWidget {
  const AuthPageScaffold({
    super.key,
    required this.child,
    this.footer,
    this.brandSize = 160,
  });

  final Widget child;
  final Widget? footer;

  /// A tela de e-mail usa um logo menor para o teclado não esconder o botão.
  final double brandSize;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.light;

    return Theme(
      data: theme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: AppColors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarColor: AppColors.lightApp,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        ),
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/images/logo_wordmark.png',
                        width: brandSize,
                        height: brandSize,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 32),
                      // Sem card: os controles brancos ficam direto sobre o
                      // fundo cinza-claro da página, que já os destaca.
                      child,
                      if (footer != null) ...[
                        const SizedBox(height: 16),
                        footer!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Não tem conta? Criar conta", abaixo do card.
class CreateAccountFooter extends StatelessWidget {
  const CreateAccountFooter({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Não tem conta? ',
          style: TextStyle(color: AppColors.lightTextSecondary, fontSize: 13),
        ),
        TextButton(
          onPressed: onPressed,
          child: const Text(
            'Criar conta',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

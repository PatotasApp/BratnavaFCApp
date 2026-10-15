import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Pílula branca de largura total usada pelas opções da tela de login (Apple,
/// Google e e-mail), sem contorno: o fundo cinza-claro da página já a destaca.
/// Mesmo estilo nas três para nenhuma opção parecer secundária.
///
/// O ícone ocupa uma coluna de largura fixa e o texto começa logo depois, à
/// esquerda. Como a coluna é igual em todos os botões, ícones e textos ficam
/// alinhados entre si — centralizar ícone e texto juntos os desalinhava,
/// porque cada rótulo tem uma largura.
class AuthOptionButton extends StatelessWidget {
  const AuthOptionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: AppColors.onDark,
          disabledBackgroundColor: AppColors.onDark,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: Row(
          children: [
            SizedBox(width: 24, child: Center(child: icon)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.lightText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

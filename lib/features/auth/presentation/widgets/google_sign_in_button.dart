import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';

/// Botão de entrar com o Google.
///
/// O glifo é o "G" oficial de quatro cores, em SVG — as diretrizes do Google
/// pedem o logotipo nas cores originais e proíbem recolori-lo. O arquivo é o
/// mesmo que o front web usa, então a marca fica idêntica nas duas pontas.
///
/// As cores vivem dentro do SVG, não em Dart. Isso é o certo aqui e também
/// atende ao theme_contract_test: são cores de marca de terceiro, que não
/// respondem ao tema do app.
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
    return SvgPicture.asset(
      'assets/images/google_g.svg',
      width: 18,
      height: 18,
      // Sem semântica: o rótulo do botão ao lado já anuncia a ação, e um
      // segundo texto faria o leitor de tela repetir "Google" duas vezes.
      excludeFromSemantics: true,
    );
  }
}

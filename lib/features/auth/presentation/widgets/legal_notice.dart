import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

/// Abre uma página do site no navegador. Avisa quando não abre, para o toque
/// não parecer ignorado.
Future<void> openLegalPage(BuildContext context, String url) async {
  final opened =
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Não foi possível abrir $url')));
  }
}

/// "Ao continuar, você concorda com os Termos de Uso e a Política de
/// Privacidade." Fica no login e no cadastro: a App Store exige que o usuário
/// aceite os termos (com tolerância zero a conteúdo ofensivo) ao criar a conta,
/// e o login social cria a conta no primeiro acesso.
class LegalNotice extends StatefulWidget {
  const LegalNotice({super.key, this.color = AppColors.lightTextSecondary});

  final Color color;

  @override
  State<LegalNotice> createState() => _LegalNoticeState();
}

class _LegalNoticeState extends State<LegalNotice> {
  late final _terms = TapGestureRecognizer()
    ..onTap = () => openLegalPage(context, AppConstants.termsOfUseUrl);
  late final _privacy = TapGestureRecognizer()
    ..onTap = () => openLegalPage(context, AppConstants.privacyPolicyUrl);

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(color: widget.color, fontSize: 12, height: 1.4);
    final link = base.copyWith(
        fontWeight: FontWeight.w600, decoration: TextDecoration.underline);
    return Text.rich(
      TextSpan(style: base, children: [
        const TextSpan(text: 'Ao continuar, você concorda com os '),
        TextSpan(text: 'Termos de Uso', style: link, recognizer: _terms),
        const TextSpan(text: ' e a '),
        TextSpan(
            text: 'Política de Privacidade', style: link, recognizer: _privacy),
        const TextSpan(text: '.'),
      ]),
      textAlign: TextAlign.center,
    );
  }
}

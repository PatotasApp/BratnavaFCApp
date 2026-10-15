import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

/// Mostra o resultado da última operação do [authNotifierProvider].
///
/// Não navega em caso de sucesso: quem redireciona é o router, quando a sessão
/// e o perfil ficam prontos. Um `context.go('/app')` daqui entraria no app
/// antes do GET /me e mostraria a tela com os fallbacks.
///
/// [onLinkRequired] recebe o e-mail quando o login com Apple esbarra numa conta
/// existente — não é falha: a tela passa a mostrar o aviso de vínculo.
void showAuthResult(
  BuildContext context,
  WidgetRef ref, {
  required String fallback,
  void Function(String? email)? onLinkRequired,
}) {
  final notifier = ref.read(authNotifierProvider.notifier);

  ref.read(authNotifierProvider).whenOrNull(
    data: (_) {
      // Resultado do vínculo da Apple. O ScaffoldMessenger é da raiz, então o
      // aviso sobrevive ao redirecionamento do router.
      final notice = notifier.takeLinkNotice();
      if (notice != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(notice)),
        );
      }
    },
    error: (error, _) {
      // Fechar o seletor do Google ou a tela da Apple não é erro.
      if (isUserCancelled(error)) return;

      if (error is AppleLinkRequiredException) {
        onLinkRequired?.call(error.email);
        return;
      }

      showAuthError(
        context,
        error is AppleLinkWrongAccountException
            ? error.message
            : authErrorMessage(error, fallback),
      );
    },
  );
}

void showAuthError(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.rose600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
}

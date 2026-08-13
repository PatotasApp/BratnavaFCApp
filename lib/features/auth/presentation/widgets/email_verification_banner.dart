import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';

/// Aviso de e-mail não verificado. Não bloqueia nada — verificar é recomendado,
/// não exigido para usar o app.
///
/// Dois motivos concretos para ele existir:
///
/// 1. Enquanto o e-mail estiver NÃO verificado, entrar pelo Google com o mesmo
///    endereço faz o Firebase REMOVER a credencial de senha da conta, e a pessoa
///    perde o login por senha sem entender por quê.
/// 2. O provisionamento no backend RECUSA vincular este UID a uma linha
///    existente com o mesmo e-mail sem `email_verified` — quem já tinha conta
///    antes da migração fica em 403 até verificar.
///
/// O botão "Já verifiquei" existe porque o Firebase não avisa o app quando a
/// verificação acontece: o link costuma ser aberto em outro aparelho, então nada
/// dispara localmente.
class EmailVerificationBanner extends ConsumerStatefulWidget {
  const EmailVerificationBanner({super.key});

  @override
  ConsumerState<EmailVerificationBanner> createState() =>
      _EmailVerificationBannerState();
}

class _EmailVerificationBannerState
    extends ConsumerState<EmailVerificationBanner> {
  bool _sending = false;
  bool _checking = false;

  Future<void> _resend() async {
    setState(() => _sending = true);

    try {
      await ref.read(firebaseAuthServiceProvider).sendEmailVerification();
      _toast('E-mail de verificação enviado.');
    } catch (error) {
      _toast(
        authErrorMessage(
          error,
          'Não foi possível enviar o e-mail de verificação.',
        ),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _recheck() async {
    setState(() => _checking = true);

    try {
      final verified =
          await ref.read(sessionProvider.notifier).recheckEmailVerified();

      _toast(
        verified
            ? 'E-mail verificado!'
            : 'Ainda não confirmamos seu e-mail. Abra o link que enviamos.',
      );
    } catch (error) {
      _toast(
        authErrorMessage(error, 'Não foi possível checar a verificação.'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.rose600 : null,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final email = session.user?.email;

    if (!session.isAuthenticated || session.emailVerified || email == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.amber950 : AppColors.amber50,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.amber900 : AppColors.amber200,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.mark_email_unread_outlined,
                size: 16,
                color: isDark ? AppColors.amber400 : AppColors.amber600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Seu e-mail $email ainda não foi verificado.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.amber200 : AppColors.amber800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _sending ? null : _resend,
                child: Text(_sending ? 'Enviando...' : 'Reenviar e-mail'),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: _checking ? null : _recheck,
                child: Text(_checking ? 'Checando...' : 'Já verifiquei'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

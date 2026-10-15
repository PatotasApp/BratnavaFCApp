import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/apple_link_notice.dart';
import '../widgets/apple_sign_in_button.dart';
import '../widgets/auth_option_button.dart';
import '../widgets/auth_page_scaffold.dart';
import '../widgets/auth_result_feedback.dart';
import '../widgets/google_sign_in_button.dart';

/// Escolha do método de login: Apple, Google ou e-mail.
///
/// E-mail e senha ficam em `/login/email`: aqui a pessoa só escolhe, e nenhuma
/// opção empurra as outras para fora da tela.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  Future<void> _submitApple() async {
    await ref.read(authNotifierProvider.notifier).loginWithApple();
    _handleResult('Falha ao entrar com a Apple.');
  }

  Future<void> _submitGoogle() async {
    await ref.read(authNotifierProvider.notifier).loginWithGoogle();
    _handleResult('Falha ao entrar com o Google.');
  }

  void _handleResult(String fallback) {
    if (!mounted) return;

    // Re-renderiza o aviso de vínculo, que lê a pendência do notifier.
    setState(() {});
    showAuthResult(context, ref, fallback: fallback);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;
    final notifier = ref.read(authNotifierProvider.notifier);
    final pendingLink = notifier.pendingAppleLink;
    final textTheme = Theme.of(context).textTheme;

    return AuthPageScaffold(
      footer: CreateAccountFooter(onPressed: () => context.push('/register')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Entre para continuar',
            textAlign: TextAlign.center,
            // Cor explícita: o `context` aqui é o de fora do Theme claro que o
            // AuthPageScaffold força, e no modo escuro o título sairia branco.
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.lightText,
            ),
          ),
          if (pendingLink != null) ...[
            const SizedBox(height: 16),
            AppleLinkNotice(
              email: pendingLink.email,
              onCancel: () => setState(notifier.cancelAppleLink),
            ),
          ],
          const SizedBox(height: 24),

          // Apple acima e do mesmo tamanho: é o que as diretrizes da Apple
          // pedem para o botão dela.
          AppleSignInButton(onPressed: isLoading ? null : _submitApple),
          const SizedBox(height: 12),
          GoogleSignInButton(onPressed: isLoading ? null : _submitGoogle),

          // Separa o login social do e-mail e senha convencional.
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(color: AppColors.lightBorder, height: 1),
          ),

          AuthOptionButton(
            onPressed: isLoading
                ? null
                // Volta com setState: o vínculo pode ter sido concluído ou
                // cancelado lá, e o aviso daqui lê a pendência do notifier.
                : () async {
                    await context.push('/login/email');
                    if (mounted) setState(() {});
                  },
            label: 'Continuar com e-mail',
            icon: const Icon(
              Icons.mail_outline,
              size: 20,
              color: AppColors.lightText,
            ),
          ),
        ],
      ),
    );
  }
}

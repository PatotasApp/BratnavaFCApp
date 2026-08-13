import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/app_button.dart';
import '../../../../shared/presentation/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

/// Redefinição de senha por e-mail.
///
/// É o **único** caminho de troca de senha que existe — inclusive para quem já
/// está logado, que chega aqui pela tela Minha conta. A API não tem endpoint de
/// senha, e o app nunca vê a senha em texto puro.
///
/// Também é por aqui que os usuários anteriores à migração entram: eles não
/// preservam a senha, e o reset marca o e-mail como verificado, que é o que
/// libera o vínculo com a linha existente no provisionamento do backend.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key, this.initialEmail});

  /// Pré-preenchido quando a tela é aberta por quem já está logado.
  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl =
      TextEditingController(text: widget.initialEmail ?? '');

  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _sending) return;

    setState(() => _sending = true);

    try {
      await ref
          .read(firebaseAuthServiceProvider)
          .sendPasswordReset(_emailCtrl.text);

      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              authErrorMessage(
                error,
                'Não foi possível enviar o e-mail de redefinição.',
              ),
            ),
            backgroundColor: AppColors.rose600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.light;

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Esqueci minha senha'),
          backgroundColor: theme.colorScheme.surface,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.lightBorder),
                  ),
                  child: _sent ? _sentBody(theme) : _formBody(theme),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sentBody(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.mark_email_read_outlined,
            size: 40, color: AppColors.emerald700),
        const SizedBox(height: 16),
        Text(
          'Verifique seu e-mail',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),

        // Mensagem neutra de propósito: o Firebase responde sucesso mesmo para
        // e-mail sem conta, por proteção contra enumeração. Afirmar que a conta
        // existe vazaria essa informação.
        Text(
          'Se existir uma conta para ${_emailCtrl.text.trim()}, o link de '
          'redefinição chegou lá. Abra o link e escolha uma senha nova.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Não achou? Confira a caixa de spam — o remetente é o Firebase, não o '
          'PatotasApp.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 24),
        AppButton(
          label: 'Voltar',
          onPressed: () => context.pop(),
          width: double.infinity,
        ),
      ],
    );
  }

  Widget _formBody(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Redefinir senha',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Informe seu e-mail e enviaremos um link para você definir uma nova '
            'senha.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),
          AppTextField(
            label: 'E-mail',
            hint: 'seu@email.com',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onEditingComplete: _submit,
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'E-mail é obrigatório.';
              if (!value.contains('@') || !value.contains('.')) {
                return 'Informe um e-mail válido.';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Enviar link de redefinição',
            onPressed: _submit,
            isLoading: _sending,
            width: double.infinity,
          ),
        ],
      ),
    );
  }
}

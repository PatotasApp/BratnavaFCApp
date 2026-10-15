import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/app_button.dart';
import '../../../../shared/presentation/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/apple_link_notice.dart';
import '../widgets/auth_page_scaffold.dart';
import '../widgets/auth_result_feedback.dart';

/// Login por e-mail e senha, aberto pela opção "Continuar com e-mail".
///
/// Se houver vínculo da Apple pendente, o e-mail já vem preenchido com o da
/// conta existente e o vínculo é concluído logo depois do login.
class EmailLoginPage extends ConsumerStatefulWidget {
  const EmailLoginPage({super.key});

  @override
  ConsumerState<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends ConsumerState<EmailLoginPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  final _passwordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(
      text: ref.read(authNotifierProvider.notifier).pendingAppleLink?.email,
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authNotifierProvider.notifier).login(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );

    if (!mounted) return;

    setState(() {});
    showAuthResult(context, ref, fallback: 'Não foi possível entrar.');
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;
    final notifier = ref.read(authNotifierProvider.notifier);
    final pendingLink = notifier.pendingAppleLink;
    final textTheme = Theme.of(context).textTheme;

    return AuthPageScaffold(
      brandSize: 96,
      footer: CreateAccountFooter(onPressed: () => context.push('/register')),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                // Sem pilha (rota aberta direto), volta para a escolha.
                onPressed: isLoading
                    ? null
                    : () => context.canPop()
                        ? context.pop()
                        : context.go('/login'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: AppColors.lightTextSecondary,
                ),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Outras opções'),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Entrar com e-mail',
              textAlign: TextAlign.center,
              // Cor explícita: o `context` aqui é o de fora do Theme claro que
              // o AuthPageScaffold força, e no modo escuro sairia branco.
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
            AppTextField(
              label: 'E-mail',
              hint: 'seu@email.com',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'E-mail é obrigatório.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Senha',
              hint: '••••••',
              controller: _passwordCtrl,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onEditingComplete: _submit,
              validator: (v) {
                if (v == null || v.length < 3) {
                  return 'Mínimo 3 caracteres.';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed:
                    isLoading ? null : () => context.push('/forgot-password'),
                child: const Text(
                  'Esqueci minha senha',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Entrar',
              onPressed: _submit,
              isLoading: isLoading,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }
}

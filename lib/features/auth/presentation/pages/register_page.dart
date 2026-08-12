import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/app_button.dart';
import '../../../../shared/presentation/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';
import '../../../../core/auth/auth_errors.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _success = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // userName não vai: o backend gera um a partir do e-mail no
    // provisionamento, e o usuário troca depois no perfil.
    await ref.read(authNotifierProvider.notifier).register(
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );

    if (!mounted) return;

    final state = ref.read(authNotifierProvider);
    state.whenOrNull(
      error: (e, _) =>
          _showError(authErrorMessage(e, 'Não foi possível criar a conta.')),
      // Sem navegação: a conta já está autenticada no Firebase e o router leva
      // para /app quando o perfil termina de carregar. Mandar para /login aqui
      // era o comportamento do fluxo antigo, em que cadastrar não logava.
      data: (_) => setState(() => _success = true),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.rose600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  // ── Brand ─────────────────────────────────────────────
                  _brand(context, isDark),
                  const SizedBox(height: 32),

                  if (_success)
                    _successBanner(context, isDark)
                  else
                    _form(context, isDark, isLoading),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Já tem conta? ',
                        style: TextStyle(
                          color:
                              isDark ? AppColors.slate400 : AppColors.slate500,
                          fontSize: 13,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text(
                          'Entrar',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _successBanner(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.emerald50,
        borderRadius: BorderRadius.circular(16),
        border: const Border.fromBorderSide(
            BorderSide(color: AppColors.emerald200)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_rounded,
              color: AppColors.emerald700, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Conta criada! Enviamos um e-mail para você confirmar seu '
              'endereço.',
              style: TextStyle(
                color: AppColors.emerald700,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _form(BuildContext context, bool isDark, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.onDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.darkApp.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Criar conta',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Preencha os dados para se cadastrar.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.slate400 : AppColors.slate500,
                  ),
            ),
            const SizedBox(height: 24),

            // Nome + Sobrenome lado a lado
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Nome',
                    hint: 'João',
                    controller: _firstNameCtrl,
                    validator: (v) => v == null || v.trim().length < 2
                        ? 'Mínimo 2 caracteres.'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    label: 'Sobrenome',
                    hint: 'Silva',
                    controller: _lastNameCtrl,
                    validator: (v) => v == null || v.trim().length < 2
                        ? 'Mínimo 2 caracteres.'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            AppTextField(
              label: 'E-mail',
              hint: 'seu@email.com',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'E-mail é obrigatório.';
                }
                if (!RegExp(r'^[\w.+\-]+@[\w\-]+\.[a-zA-Z]{2,}$')
                    .hasMatch(v.trim())) {
                  return 'E-mail inválido.';
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
              // 6 é o mínimo do Firebase: abaixo disso ele recusa com
              // `weak-password`, e validar aqui evita a ida ao servidor.
              validator: (v) =>
                  v == null || v.length < 6 ? 'Mínimo 6 caracteres.' : null,
            ),
            const SizedBox(height: 24),

            AppButton(
              label: 'Criar conta',
              onPressed: _submit,
              isLoading: isLoading,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _brand(BuildContext context, bool isDark) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate800 : AppColors.slate900,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: const Text(
            'BFC',
            style: TextStyle(
              color: AppColors.onDark,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'PatotasApp',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

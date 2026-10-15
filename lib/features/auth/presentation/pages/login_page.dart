import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/auth/auth_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/app_button.dart';
import '../../../../shared/presentation/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/apple_sign_in_button.dart';
import '../widgets/google_sign_in_button.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

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

    _handleResult('Não foi possível entrar.');
  }

  Future<void> _submitGoogle() async {
    await ref.read(authNotifierProvider.notifier).loginWithGoogle();

    _handleResult('Falha ao entrar com o Google.');
  }

  Future<void> _submitApple() async {
    await ref.read(authNotifierProvider.notifier).loginWithApple();

    _handleResult('Falha ao entrar com a Apple.');
  }

  /// Não navega em caso de sucesso: quem redireciona é o router, quando a sessão
  /// e o perfil ficam prontos. Um `context.go('/app')` daqui entraria no app
  /// antes do GET /me e mostraria a tela com os fallbacks.
  void _handleResult(String fallback) {
    if (!mounted) return;

    final notifier = ref.read(authNotifierProvider.notifier);

    // Re-renderiza o aviso de vínculo, que lê a pendência do notifier.
    setState(() {});

    ref.read(authNotifierProvider).whenOrNull(
      data: (_) {
        // Resultado do vínculo da Apple. O ScaffoldMessenger é da raiz, então
        // o aviso sobrevive ao redirecionamento do router.
        final notice = notifier.takeLinkNotice();
        if (notice != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(notice)),
          );
        }
      },
      error: (error, _) {
        // Cancelar o seletor de conta do Google não é erro.
        if (isUserCancelled(error)) return;

        // Não é falha: a tela passa a mostrar o aviso de vínculo.
        if (error is AppleLinkRequiredException) {
          if (error.email != null) _emailCtrl.text = error.email!;
          return;
        }

        if (error is AppleLinkWrongAccountException) {
          _showError(error.message);
          return;
        }

        _showError(authErrorMessage(error, fallback));
      },
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
    final pendingLink =
        ref.read(authNotifierProvider.notifier).pendingAppleLink;
    final loginTheme = AppTheme.light;

    return Theme(
      data: loginTheme,
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
                      // ── Brand ─────────────────────────────────────────────
                      _BrandHeader(),
                      const SizedBox(height: 32),

                      // ── Card ──────────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: loginTheme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.lightBorder),
                          boxShadow: [
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
                                'Entrar',
                                style: loginTheme.textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Bem-vindo de volta!',
                                style: loginTheme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.lightTextSecondary,
                                ),
                              ),
                              if (pendingLink != null) ...[
                                const SizedBox(height: 16),
                                _AppleLinkNotice(
                                  email: pendingLink.email,
                                  onCancel: () => setState(
                                    ref
                                        .read(authNotifierProvider.notifier)
                                        .cancelAppleLink,
                                  ),
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
                                  onPressed: isLoading
                                      ? null
                                      : () => context.push('/forgot-password'),
                                  child: const Text(
                                    'Esqueci minha senha',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
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
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Divider(
                                        color: AppColors.lightBorder,
                                        height: 1),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text(
                                      'OU',
                                      style: loginTheme.textTheme.bodySmall
                                          ?.copyWith(
                                        color: AppColors.lightTextSecondary,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    child: Divider(
                                        color: AppColors.lightBorder,
                                        height: 1),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: AppleSignInButton(
                                      onPressed:
                                          isLoading ? null : _submitApple,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: GoogleSignInButton(
                                      onPressed:
                                          isLoading ? null : _submitGoogle,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Link para cadastro ─────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Não tem conta? ',
                            style: TextStyle(
                              color: AppColors.lightTextSecondary,
                              fontSize: 13,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/register'),
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
                      ),
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

/// Aviso de que o login com Apple esbarrou numa conta existente e será
/// vinculado a ela no próximo login pelo método antigo.
class _AppleLinkNotice extends StatelessWidget {
  const _AppleLinkNotice({required this.email, required this.onCancel});

  final String? email;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warningLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Já existe uma conta com ${email ?? 'este e-mail'}. Entre com o '
            'método que você já usa (Google ou e-mail e senha) para vincular '
            'a Apple a ela.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.lightText),
          ),
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
            ),
            child: const Text('Cancelar vínculo'),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_wordmark.png',
      width: 160,
      height: 160,
      fit: BoxFit.contain,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_errors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Troca de e-mail no padrão verify-before-update: o link de confirmação vai
/// para o endereço **novo** e a troca só se aplica quando a pessoa clica. O
/// Firebase ainda avisa o endereço antigo, com opção de reverter.
///
/// A API não participa: o e-mail é atributo espelhado do Firebase, e o
/// `SyncEmailFromTokenAsync` atualiza a coluna sozinho no acesso seguinte. A
/// identidade continua sendo o GUID interno.
class ChangeEmailSheet extends ConsumerStatefulWidget {
  const ChangeEmailSheet({super.key, required this.currentEmail});

  final String currentEmail;

  @override
  ConsumerState<ChangeEmailSheet> createState() => _ChangeEmailSheetState();
}

class _ChangeEmailSheetState extends ConsumerState<ChangeEmailSheet> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _confirm = TextEditingController();

  bool _saving = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref
          .read(firebaseAuthServiceProvider)
          .changeEmail(_email.text.trim());

      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = authErrorMessage(
            error,
            'Não foi possível iniciar a troca de e-mail.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Alterar e-mail',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: 12),
              ],
              if (_sent)
                Text(
                  'Enviamos um link de confirmação para ${_email.text.trim()}. '
                  'A troca só vale depois que você abrir esse link — até lá, '
                  'continue entrando com ${widget.currentEmail}.',
                  style: theme.textTheme.bodyMedium,
                )
              else
                _form(theme),
              const SizedBox(height: 20),
              if (_sent)
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                )
              else
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.mail_outline),
                  label: Text(_saving ? 'Enviando...' : 'Enviar confirmação'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Seu e-mail atual é ${widget.currentEmail}. Para trocar, informe o '
            'novo endereço — enviaremos um link de confirmação para ele.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Novo e-mail'),
            validator: _validateEmail,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirm,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration:
                const InputDecoration(labelText: 'Confirmar novo e-mail'),
            validator: (value) {
              final error = _validateEmail(value);
              if (error != null) return error;
              if (value!.trim().toLowerCase() !=
                  _email.text.trim().toLowerCase()) {
                return 'Os e-mails não conferem.';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim().toLowerCase() ?? '';

    if (email.isEmpty) return 'Informe o novo e-mail.';
    if (!email.contains('@') || !email.contains('.')) {
      return 'Informe um e-mail válido.';
    }
    if (email == widget.currentEmail.trim().toLowerCase()) {
      return 'Este já é o seu e-mail.';
    }
    return null;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/session_provider.dart';
import '../../../members/domain/entities/app_user.dart';
import '../../../members/presentation/providers/members_provider.dart';

class EditAccountProfileSheet extends ConsumerStatefulWidget {
  final AppUser user;

  const EditAccountProfileSheet({super.key, required this.user});

  @override
  ConsumerState<EditAccountProfileSheet> createState() =>
      _EditAccountProfileSheetState();
}

class _EditAccountProfileSheetState
    extends ConsumerState<EditAccountProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _userName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  DateTime? _birthDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController(text: widget.user.firstName);
    _lastName = TextEditingController(text: widget.user.lastName);
    _userName = TextEditingController(text: widget.user.userName);
    _email = TextEditingController(text: widget.user.email);
    _phone = TextEditingController(text: widget.user.phone ?? '');
    _birthDate = _parseDate(widget.user.birthDate);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _userName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final raw = value.trim();
    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;
    final parts = raw.split('/');
    if (parts.length != 3) return null;
    return DateTime.tryParse(
      '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}',
    );
  }

  String get _formattedBirthDate {
    final date = _birthDate;
    if (date == null) return 'Não informada';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Data de nascimento',
    );
    if (selected != null && mounted) {
      setState(() => _birthDate = selected);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      // PUT /api/users/me, não /api/users/{id}: o endpoint por id passou a
      // exigir Admin/GodMode, e usuário comum tomava 403 ao salvar o próprio
      // perfil.
      //
      // O e-mail não vai no payload — é read-only na API, gerenciado no
      // Firebase, e tem fluxo próprio com confirmação no endereço novo.
      await ref.read(authDataSourceProvider).updateMe(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            userName: _userName.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            birthDate: _birthDate,
          );

      // Relê o perfil da fonte autoritativa em vez de remendar o store com o
      // que digitamos: o backend normaliza userName e pode recusar o telefone.
      await ref.read(sessionProvider.notifier).loadProfile();
      ref.invalidate(myProfileProvider);

      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              extractDioError(error, 'Não foi possível atualizar seus dados.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value) =>
      value?.trim().isEmpty == true ? 'Este campo é obrigatório.' : null;

  String? _userNameValidator(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;
    if (value!.contains(RegExp(r'\s'))) {
      return 'O usuário não pode ter espaços.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.manage_accounts_outlined,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Editar meus dados',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Atualize as informações da sua conta',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstName,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Nome'),
                        validator: _required,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _lastName,
                        textCapitalization: TextCapitalization.words,
                        decoration:
                            const InputDecoration(labelText: 'Sobrenome'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _userName,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Usuário',
                    prefixText: '@',
                  ),
                  validator: _userNameValidator,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  readOnly: true,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    helperText:
                        'Use "Alterar e-mail" em Segurança — a confirmação vai '
                        'para o endereço novo.',
                    helperMaxLines: 3,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone',
                    hintText: 'Opcional',
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _selectBirthDate,
                  borderRadius: BorderRadius.circular(16),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data de nascimento',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(_formattedBirthDate),
                  ),
                ),
                // Sem "Remover data": no PUT /me a ausência do campo significa
                // MANTER o valor atual, não limpar. O botão prometeria algo que
                // o endpoint não faz — apagar exige o fluxo administrativo.
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Salvando...' : 'Salvar alterações'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

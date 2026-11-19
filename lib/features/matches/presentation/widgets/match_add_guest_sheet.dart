import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';

typedef AddMatchGuestCallback = Future<bool> Function(
  String name,
  bool isGoalkeeper,
  int? starRating,
);

Future<bool?> showMatchAddGuestSheet({
  required BuildContext context,
  required GroupIcons icons,
  required AddMatchGuestCallback onSubmit,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MatchAddGuestSheet(icons: icons, onSubmit: onSubmit),
  );
}

class MatchAddGuestSheet extends StatefulWidget {
  const MatchAddGuestSheet({
    super.key,
    required this.icons,
    required this.onSubmit,
  });

  final GroupIcons icons;
  final AddMatchGuestCallback onSubmit;

  @override
  State<MatchAddGuestSheet> createState() => _MatchAddGuestSheetState();
}

class _MatchAddGuestSheetState extends State<MatchAddGuestSheet> {
  final _nameController = TextEditingController();
  bool _isGoalkeeper = false;
  int? _starRating;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Informe o nome do convidado.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final success = await widget.onSubmit(name, _isGoalkeeper, _starRating);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _saving = false;
      _error = 'Não foi possível adicionar o convidado.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: isDark ? AppColors.slate900 : AppColors.lightCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_add_alt_1_outlined,
                          color: AppColors.warning),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Adicionar convidado',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800)),
                          Text('Será incluído nesta partida',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.slate400)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar',
                      onPressed:
                          _saving ? null : () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  key: const Key('match-guest-name-field'),
                  controller: _nameController,
                  autofocus: true,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saving ? null : _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Nome do convidado',
                    hintText: 'Ex.: Zé da Pelada',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  key: const Key('match-guest-goalkeeper-switch'),
                  contentPadding: EdgeInsets.zero,
                  value: _isGoalkeeper,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _isGoalkeeper = value),
                  title: const Text('Goleiro',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  secondary: renderGroupIcon(widget.icons.goalkeeper, size: 18),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Nível estimado (opcional)',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                    if (_starRating != null)
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => setState(() => _starRating = null),
                        child: const Text('Limpar'),
                      ),
                  ],
                ),
                Row(
                  key: const Key('match-guest-star-rating'),
                  children: List.generate(5, (index) {
                    final value = index + 1;
                    final selected =
                        _starRating != null && value <= _starRating!;
                    return IconButton(
                      tooltip: '$value ${value == 1 ? 'estrela' : 'estrelas'}',
                      visualDensity: VisualDensity.compact,
                      onPressed: _saving
                          ? null
                          : () => setState(() => _starRating = value),
                      icon: Icon(
                        selected
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color:
                            selected ? AppColors.warning : AppColors.slate400,
                      ),
                    );
                  }),
                ),
                const Text(
                  'A nota ajuda a equilibrar os times nas primeiras partidas.',
                  style: TextStyle(fontSize: 11, color: AppColors.slate400),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.prototypeDanger)),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: const Key('submit-match-guest-button'),
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.onDark),
                        )
                      : const Icon(Icons.add),
                  label: Text(_saving ? 'Adicionando...' : 'Adicionar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

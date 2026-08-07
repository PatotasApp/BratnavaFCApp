import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import 'payment_sheet_widgets.dart';

class CreateExtraChargeSheet extends StatefulWidget {
  final List<({String id, String name})> players;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final VoidCallback onSaved;

  const CreateExtraChargeSheet({
    super.key,
    required this.players,
    required this.onSubmit,
    required this.onSaved,
  });

  @override
  State<CreateExtraChargeSheet> createState() => _CreateExtraChargeSheetState();
}

class _CreateExtraChargeSheetState extends State<CreateExtraChargeSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _dueDateCtrl = TextEditingController();
  late Set<String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.players.map((p) => p.id));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _dueDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      _dueDateCtrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text);

    if (name.isEmpty || amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nome e valor são obrigatórios'),
        backgroundColor: AppColors.rose500,
      ));
      return;
    }
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecione ao menos um jogador'),
        backgroundColor: AppColors.rose500,
      ));
      return;
    }

    setState(() => _saving = true);
    try {
      final dto = <String, dynamic>{
        'name': name,
        'amount': amount,
        'playerIds': _selected.toList(),
      };
      final desc = _descCtrl.text.trim();
      if (desc.isNotEmpty) dto['description'] = desc;
      final due = _dueDateCtrl.text.trim();
      if (due.isNotEmpty) dto['dueDate'] = due;

      await widget.onSubmit(dto);

      if (mounted) {
        widget.onSaved();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao criar cobrança: $e'),
          backgroundColor: AppColors.rose500,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.slate700 : AppColors.slate200;
    final divColor = isDark ? AppColors.slate800 : AppColors.slate50;
    final allSelected = _selected.length == widget.players.length;

    return SheetContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHandle(isDark: isDark),
          const SizedBox(height: 16),
          Text('Nova cobrança extra',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.onDark : AppColors.slate900,
              )),
          const SizedBox(height: 20),
          FieldLabel('Nome *', isDark),
          const SizedBox(height: 6),
          SheetField(
            controller: _nameCtrl,
            isDark: isDark,
            hint: 'Ex: Churrasco da patota',
          ),
          const SizedBox(height: 12),
          FieldLabel('Descrição', isDark),
          const SizedBox(height: 6),
          SheetField(
            controller: _descCtrl,
            isDark: isDark,
            hint: 'Opcional',
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FieldLabel('Valor (R\$) *', isDark),
                    const SizedBox(height: 6),
                    SheetField(
                      controller: _amountCtrl,
                      isDark: isDark,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                      ],
                    ),
                  ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FieldLabel('Vencimento', isDark),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _pickDate,
                      child: AbsorbPointer(
                        child: SheetField(
                          controller: _dueDateCtrl,
                          isDark: isDark,
                          hint: 'Selecionar',
                        ),
                      ),
                    ),
                  ]),
            ),
          ]),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FieldLabel('Jogadores *', isDark),
              GestureDetector(
                onTap: () => setState(() {
                  _selected = allSelected
                      ? {}
                      : Set.from(widget.players.map((p) => p.id));
                }),
                child: Text(
                  allSelected ? 'Desmarcar todos' : 'Marcar todos',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.slate400 : AppColors.slate500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.players.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: divColor),
                itemBuilder: (_, i) {
                  final p = widget.players[i];
                  final checked = _selected.contains(p.id);
                  return InkWell(
                    onTap: () => setState(() {
                      if (checked)
                        _selected.remove(p.id);
                      else
                        _selected.add(p.id);
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(children: [
                        Checkbox(
                          value: checked,
                          onChanged: (_) => setState(() {
                            if (checked)
                              _selected.remove(p.id);
                            else
                              _selected.add(p.id);
                          }),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 8),
                        Text(p.name,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.onDark
                                  : AppColors.slate800,
                            )),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${_selected.length} de ${widget.players.length} selecionados',
              style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.slate500 : AppColors.slate400),
            ),
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: ActionBtn(
                label: 'Criar cobrança',
                icon: Icons.add_circle_outline,
                color: isDark ? AppColors.onDark : AppColors.slate900,
                foregroundColor: isDark ? AppColors.slate900 : AppColors.onDark,
                loading: _saving,
                onTap: _submit,
              ),
            ),
            const SizedBox(width: 8),
            OutlineBtn(
              label: 'Cancelar',
              isDark: isDark,
              padH: 16,
              onTap: () => Navigator.of(context).pop(),
            ),
          ]),
        ],
      ),
    );
  }
}

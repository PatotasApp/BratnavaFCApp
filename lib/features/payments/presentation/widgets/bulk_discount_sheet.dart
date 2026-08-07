import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../domain/entities/payment_entities.dart';
import 'payment_sheet_widgets.dart';

class BulkDiscountSheet extends StatefulWidget {
  final String groupId;
  final ExtraCharge charge;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final VoidCallback onSaved;

  const BulkDiscountSheet({
    super.key,
    required this.groupId,
    required this.charge,
    required this.onSubmit,
    required this.onSaved,
  });

  @override
  State<BulkDiscountSheet> createState() => _BulkDiscountSheetState();
}

class _BulkDiscountSheetState extends State<BulkDiscountSheet> {
  final _discCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  late Set<String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(
      widget.charge.payments.where((p) => !p.isPaid).map((p) => p.playerId),
    );
  }

  @override
  void dispose() {
    _discCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final discount = double.tryParse(_discCtrl.text) ?? 0;
    if (discount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Informe um valor de desconto'),
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
        'discount': discount,
        'playerIds': _selected.toList(),
      };
      final reason = _reasonCtrl.text.trim();
      if (reason.isNotEmpty) dto['discountReason'] = reason;

      await widget.onSubmit(dto);

      if (mounted) {
        widget.onSaved();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao aplicar desconto: $e'),
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
    final sub = isDark ? AppColors.slate400 : AppColors.slate500;
    final allPlayers = widget.charge.payments;
    final allSelected = _selected.length == allPlayers.length;
    final discount = double.tryParse(_discCtrl.text) ?? 0;

    return SheetContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHandle(isDark: isDark),
          const SizedBox(height: 16),
          Text('Desconto em massa',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.onDark : AppColors.slate900,
              )),
          const SizedBox(height: 4),
          Text(
            'Cobrança: ${widget.charge.name} · R\$ ${widget.charge.amount.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 13, color: sub),
          ),
          const SizedBox(height: 20),
          FieldLabel('Desconto (R\$) *', isDark),
          const SizedBox(height: 6),
          SheetField(
            controller: _discCtrl,
            isDark: isDark,
            hint: '0,00',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
            ],
          ),
          const SizedBox(height: 12),
          FieldLabel('Motivo (opcional)', isDark),
          const SizedBox(height: 6),
          SheetField(
            controller: _reasonCtrl,
            isDark: isDark,
            hint: 'Ex: Desconto de fidelidade',
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FieldLabel('Jogadores *', isDark),
              GestureDetector(
                onTap: () => setState(() {
                  _selected = allSelected
                      ? {}
                      : Set.from(allPlayers.map((p) => p.playerId));
                }),
                child: Text(
                  allSelected ? 'Desmarcar todos' : 'Marcar todos',
                  style: TextStyle(
                    fontSize: 12,
                    color: sub,
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
                itemCount: allPlayers.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: divColor),
                itemBuilder: (_, i) {
                  final p = allPlayers[i];
                  final checked = _selected.contains(p.playerId);
                  return InkWell(
                    onTap: () => setState(() {
                      if (checked)
                        _selected.remove(p.playerId);
                      else
                        _selected.add(p.playerId);
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(children: [
                        Checkbox(
                          value: checked,
                          onChanged: (_) => setState(() {
                            if (checked)
                              _selected.remove(p.playerId);
                            else
                              _selected.add(p.playerId);
                          }),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ConfiguredPlayerName(
                            groupId: widget.groupId,
                            name: p.playerName,
                            isGoalkeeper: p.isGoalkeeper,
                            iconSize: 13,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.onDark
                                  : AppColors.slate800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: p.isPaid
                                ? AppColors.green100
                                : AppColors.rose50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            p.isPaid ? 'Pago' : 'Pendente',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: p.isPaid
                                  ? AppColors.primaryPressed
                                  : AppColors.rose500,
                            ),
                          ),
                        ),
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
              '${_selected.length} de ${allPlayers.length} selecionados',
              style: TextStyle(fontSize: 11, color: sub),
            ),
          ),
          if (discount > 0 && _selected.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.amber50,
                border: Border.all(color: AppColors.amber200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Aplicará R\$ ${discount.toStringAsFixed(2)} de desconto para '
                '${_selected.length} jogador${_selected.length != 1 ? 'es' : ''}.',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.warningLight),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: ActionBtn(
                label: 'Aplicar desconto',
                icon: Icons.monetization_on_outlined,
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

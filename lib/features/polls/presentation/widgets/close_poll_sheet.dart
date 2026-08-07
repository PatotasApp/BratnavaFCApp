import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'poll_form_widgets.dart';

class ClosePollSheet extends StatefulWidget {
  final String pollTitle;

  const ClosePollSheet({super.key, required this.pollTitle});

  @override
  State<ClosePollSheet> createState() => _ClosePollSheetState();
}

class _ClosePollSheetState extends State<ClosePollSheet> {
  bool _createEvent = false;
  late final TextEditingController _titleCtrl;
  final _descCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _icon = '';
  String _costType = '';

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.pollTitle);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_createEvent) {
      if (_dateCtrl.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe a data do evento.')),
        );
        return;
      }
      if (_titleCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe o título do evento.')),
        );
        return;
      }
    }

    Navigator.of(context).pop({
      'createEvent': _createEvent,
      'eventTitle': _createEvent ? _titleCtrl.text.trim() : null,
      'eventDescription':
          _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      'eventDate': _createEvent ? _dateCtrl.text : null,
      'eventTime': _timeCtrl.text.isNotEmpty ? _timeCtrl.text : null,
      'eventIcon': _icon.isNotEmpty ? _icon : null,
      'costType': _costType.isNotEmpty ? _costType : null,
      'costAmount': _amountCtrl.text.isNotEmpty
          ? double.tryParse(_amountCtrl.text)
          : null,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : AppColors.onDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.slate300,
                    borderRadius: BorderRadius.circular(2))),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: AppColors.amber500,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.lock_outlined,
                        color: AppColors.onDark, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Encerrar votação',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      Text(widget.pollTitle,
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.slate400
                                  : AppColors.slate500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  // Toggle
                  PollSectionCard(
                    isDark: isDark,
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month_outlined,
                            size: 16, color: AppColors.info),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Criar evento no calendário',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              Text('Com base no resultado desta votação',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppColors.slate400
                                          : AppColors.slate500)),
                            ],
                          ),
                        ),
                        Switch(
                          value: _createEvent,
                          onChanged: (v) => setState(() => _createEvent = v),
                        ),
                      ],
                    ),
                  ),

                  if (_createEvent) ...[
                    const SizedBox(height: 12),
                    _field('Título *', _titleCtrl, isDark),
                    const SizedBox(height: 10),
                    _field('Descrição (opcional)', _descCtrl, isDark,
                        maxLines: 2),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: PollDateField(
                              label: 'Data *',
                              controller: _dateCtrl,
                              isDark: isDark)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: PollTimeField(
                              label: 'Horário (opcional)',
                              controller: _timeCtrl,
                              isDark: isDark)),
                    ]),
                    const SizedBox(height: 10),
                    PollIconPicker(
                        selected: _icon,
                        onSelect: (v) => setState(() => _icon = v),
                        isDark: isDark),
                    const SizedBox(height: 10),
                    PollCostPicker(
                      selected: _costType,
                      amountCtrl: _amountCtrl,
                      onSelect: (v) => setState(() => _costType = v),
                      isDark: isDark,
                    ),
                  ],

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _confirm,
                          icon: const Icon(Icons.lock_outlined, size: 15),
                          label: const Text('Encerrar'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warningLight,
                              foregroundColor: AppColors.onDark),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, bool isDark,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.slate300 : AppColors.slate600)),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: const InputDecoration(
              isDense: true, contentPadding: EdgeInsets.all(10)),
        ),
      ],
    );
  }
}

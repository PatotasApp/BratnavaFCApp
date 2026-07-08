import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/polls_remote_datasource.dart';
import '../../domain/entities/poll_detail.dart';
import '../providers/polls_provider.dart';
import 'poll_form_widgets.dart';

class CreateEventSheet extends ConsumerStatefulWidget {
  final String groupId;
  final ValueChanged<PollDetail> onCreated;

  const CreateEventSheet(
      {super.key, required this.groupId, required this.onCreated});

  @override
  ConsumerState<CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends ConsumerState<CreateEventSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _deadlineDateCtrl = TextEditingController();
  final _deadlineTimeCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _icon = '';
  String _costType = '';
  bool _showVotes = true;
  bool _allowGuests = false;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _locationCtrl.dispose();
    _deadlineDateCtrl.dispose();
    _deadlineTimeCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  PollsRemoteDataSource get _ds => ref.read(pollsDsProvider);

  Future<void> _create() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Informe o título.')));
      return;
    }
    if (_dateCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe a data do evento.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final poll = await _ds.createEventPoll(widget.groupId, {
        'title': _titleCtrl.text.trim(),
        'description':
            _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
        'eventDate': _dateCtrl.text,
        'eventTime': _timeCtrl.text.isNotEmpty ? _timeCtrl.text : null,
        'eventLocation': _locationCtrl.text.trim().isNotEmpty
            ? _locationCtrl.text.trim()
            : null,
        'eventIcon': _icon.isNotEmpty ? _icon : null,
        'costType': _costType.isNotEmpty ? _costType : null,
        'costAmount': _amountCtrl.text.isNotEmpty
            ? double.tryParse(_amountCtrl.text)
            : null,
        'deadlineDate':
            _deadlineDateCtrl.text.isNotEmpty ? _deadlineDateCtrl.text : null,
        'deadlineTime':
            _deadlineTimeCtrl.text.isNotEmpty ? _deadlineTimeCtrl.text : null,
        'showVotes': _showVotes,
        'allowGuests': _allowGuests,
      });
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCreated(poll);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao criar: $e'),
            backgroundColor: AppColors.rose500));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : Colors.white,
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
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(children: [
                Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: AppColors.slate900,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.calendar_today_outlined,
                        color: Colors.white, size: 18)),
                const SizedBox(width: 10),
                const Text('Novo Evento',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop()),
              ]),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
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
                  _field('Local (opcional)', _locationCtrl, isDark,
                      icon: Icons.location_on_outlined),
                  const SizedBox(height: 12),
                  PollIconPicker(
                      selected: _icon,
                      onSelect: (v) => setState(() => _icon = v),
                      isDark: isDark),
                  const SizedBox(height: 12),
                  PollCostPicker(
                      selected: _costType,
                      amountCtrl: _amountCtrl,
                      onSelect: (v) => setState(() => _costType = v),
                      isDark: isDark),
                  const SizedBox(height: 12),
                  Text('Prazo RSVP (opcional)',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.slate300
                              : AppColors.slate600)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                        child: PollDateField(
                            label: 'Data',
                            controller: _deadlineDateCtrl,
                            isDark: isDark)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: PollTimeField(
                            label: 'Hora',
                            controller: _deadlineTimeCtrl,
                            isDark: isDark)),
                  ]),
                  const SizedBox(height: 12),
                  PollSectionCard(
                      isDark: isDark,
                      child: Row(children: [
                        Icon(Icons.visibility_outlined,
                            size: 16,
                            color: isDark
                                ? AppColors.slate300
                                : AppColors.slate600),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              const Text('Votos visíveis',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              Text('Todos veem quem respondeu o quê',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppColors.slate400
                                          : AppColors.slate500)),
                            ])),
                        Switch(
                            value: _showVotes,
                            onChanged: (v) => setState(() => _showVotes = v)),
                      ])),
                  const SizedBox(height: 10),
                  PollSectionCard(
                      isDark: isDark,
                      child: Row(children: [
                        Icon(Icons.group_outlined,
                            size: 16,
                            color: isDark
                                ? AppColors.slate300
                                : AppColors.slate600),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              const Text('Permitir convidados',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                  'Quem confirmar presenca pode adicionar acompanhantes',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppColors.slate400
                                          : AppColors.slate500)),
                            ])),
                        Switch(
                            value: _allowGuests,
                            onChanged: (v) => setState(() => _allowGuests = v)),
                      ])),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _create,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Criar Evento'),
                    ),
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
      {int maxLines = 1, IconData? icon}) {
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
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.all(10),
            suffixIcon: icon != null ? Icon(icon, size: 16) : null,
          ),
        ),
      ],
    );
  }
}

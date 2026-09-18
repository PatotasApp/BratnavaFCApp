import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/calendar_remote_datasource.dart';
import '../../domain/entities/calendar_event.dart';

class CreateEditEventSheet extends StatefulWidget {
  final String groupId;
  final CalendarRemoteDataSource datasource;
  final List<CalendarCategory> categories;
  final CalendarEvent? event; // null = criar
  final String? initialDate;
  final VoidCallback onSaved;

  const CreateEditEventSheet({
    super.key,
    required this.groupId,
    required this.datasource,
    required this.categories,
    this.event,
    this.initialDate,
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required String groupId,
    required CalendarRemoteDataSource datasource,
    required List<CalendarCategory> categories,
    CalendarEvent? event,
    String? initialDate,
    required VoidCallback onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => CreateEditEventSheet(
        groupId: groupId,
        datasource: datasource,
        categories: categories,
        event: event,
        initialDate: initialDate,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<CreateEditEventSheet> createState() => _CreateEditEventSheetState();
}

class _CreateEditEventSheetState extends State<CreateEditEventSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();

  late String _date;
  bool _timeTBD = false;
  String? _categoryId;
  bool _saving = false;

  bool get _isEdit => widget.event != null;

  @override
  void initState() {
    super.initState();
    final ev = widget.event;
    if (ev != null) {
      _titleCtrl.text = ev.title;
      _descCtrl.text = ev.description ?? '';
      _timeCtrl.text = ev.time ?? '';
      _date = ev.date;
      _timeTBD = ev.timeTBD;
      _categoryId = ev.categoryId;
    } else {
      _date = widget.initialDate ?? _todayStr();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  String _todayStr() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_date) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _date =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _pickTime() async {
    if (_timeTBD) return;
    var initial = TimeOfDay.now();
    final parts = _timeCtrl.text.split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) {
        initial = TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
      }
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      // Sempre 24h e HH:mm — é o formato que o backend valida (TimeOnly.TryParse).
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _timeCtrl.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Título é obrigatório')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final dto = {
        'type': 'manual',
        'title': title,
        'date': _date,
        'timeTBD': _timeTBD,
        if (!_timeTBD && _timeCtrl.text.isNotEmpty)
          'time': _timeCtrl.text.trim(),
        if (_descCtrl.text.isNotEmpty) 'description': _descCtrl.text.trim(),
        if (_categoryId != null) 'categoryId': _categoryId,
      };

      if (_isEdit) {
        await widget.datasource
            .updateEvent(widget.groupId, widget.event!.id!, dto);
      } else {
        await widget.datasource.createEvent(widget.groupId, dto);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : AppColors.onDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate700 : AppColors.slate200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Título do sheet
                Text(
                  _isEdit ? 'Editar evento' : 'Novo evento',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.onDark : AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 20),

                // Título do evento
                _label('Título', isDark),
                const SizedBox(height: 6),
                _field(
                    controller: _titleCtrl,
                    hint: 'Ex: Treino extra',
                    isDark: isDark),
                const SizedBox(height: 14),

                // Data
                _label('Data', isDark),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color:
                              isDark ? AppColors.slate700 : AppColors.slate200),
                      borderRadius: BorderRadius.circular(12),
                      color: isDark ? AppColors.slate800 : AppColors.slate50,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 16,
                            color: isDark
                                ? AppColors.slate400
                                : AppColors.slate500),
                        const SizedBox(width: 10),
                        Text(
                          _date,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? AppColors.slate200
                                : AppColors.slate700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Horário
                _label('Horário', isDark),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _timeTBD ? null : _pickTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: isDark
                                    ? AppColors.slate700
                                    : AppColors.slate200),
                            borderRadius: BorderRadius.circular(12),
                            color: _timeTBD
                                ? (isDark
                                    ? AppColors.slate900
                                    : AppColors.slate100)
                                : (isDark
                                    ? AppColors.slate800
                                    : AppColors.slate50),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.schedule_outlined,
                                  size: 16,
                                  color: isDark
                                      ? AppColors.slate400
                                      : AppColors.slate500),
                              const SizedBox(width: 10),
                              Text(
                                _timeCtrl.text.isEmpty
                                    ? 'Selecionar'
                                    : _timeCtrl.text,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _timeCtrl.text.isEmpty
                                      ? (isDark
                                          ? AppColors.slate600
                                          : AppColors.slate400)
                                      : (isDark
                                          ? AppColors.slate200
                                          : AppColors.slate700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: _timeTBD,
                          onChanged: (v) => setState(() {
                            _timeTBD = v ?? false;
                            if (_timeTBD) _timeCtrl.clear();
                          }),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Text(
                          'A confirmar',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.slate400
                                : AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Categoria
                if (widget.categories.isNotEmpty) ...[
                  _label('Categoria', isDark),
                  const SizedBox(height: 6),
                  _CategoryDropdown(
                    categories: widget.categories,
                    value: _categoryId,
                    isDark: isDark,
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                  const SizedBox(height: 14),
                ],

                // Descrição
                _label('Descrição (opcional)', isDark),
                const SizedBox(height: 6),
                _field(
                  controller: _descCtrl,
                  hint: 'Detalhes do evento...',
                  isDark: isDark,
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                // Botão salvar
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          isDark ? AppColors.onDark : AppColors.slate900,
                      foregroundColor:
                          isDark ? AppColors.slate900 : AppColors.onDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onDark,
                            ),
                          )
                        : Text(
                            _isEdit ? 'Salvar alterações' : 'Criar evento',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text, bool isDark) => Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.slate400 : AppColors.slate500,
          letterSpacing: .3,
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    bool enabled = true,
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboard,
      style: TextStyle(
        fontSize: 14,
        color: isDark ? AppColors.slate200 : AppColors.slate800,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: isDark ? AppColors.slate600 : AppColors.slate400),
        filled: true,
        fillColor: isDark ? AppColors.slate800 : AppColors.slate50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark ? AppColors.slate700 : AppColors.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark ? AppColors.slate700 : AppColors.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark ? AppColors.slate400 : AppColors.slate500,
              width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final List<CalendarCategory> categories;
  final String? value;
  final bool isDark;
  final void Function(String?) onChanged;

  const _CategoryDropdown({
    required this.categories,
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      DropdownMenuItem<String>(
        value: null,
        child: Text('Sem categoria',
            style: TextStyle(
              color: isDark ? AppColors.slate400 : AppColors.slate500,
              fontSize: 14,
            )),
      ),
      ...categories.map((c) => DropdownMenuItem<String>(
            value: c.id,
            child: Text(c.name,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.slate200 : AppColors.slate700,
                )),
          )),
    ];

    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: isDark ? AppColors.slate800 : AppColors.slate50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark ? AppColors.slate700 : AppColors.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark ? AppColors.slate700 : AppColors.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark ? AppColors.slate400 : AppColors.slate500,
              width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      dropdownColor: isDark ? AppColors.slate800 : AppColors.onDark,
    );
  }
}

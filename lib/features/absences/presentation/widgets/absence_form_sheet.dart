import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/absence.dart';

// ── Absence type options (mirrors absenceIcons.ts) ────────────────────────────

const _kAbsenceTypes = [
  (1, 'Viagem', Icons.flight_outlined),
  (2, 'Dept. Médico', Icons.local_hospital_outlined),
  (3, 'Pessoal', Icons.favorite_border),
  (4, 'Outros', Icons.more_horiz_outlined),
];

// ── Date helpers ──────────────────────────────────────────────────────────────

String _toApiDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime? _fromApiDate(String? s) {
  if (s == null || s.isEmpty) return null;
  final parts = s.split('-');
  if (parts.length != 3) return null;
  return DateTime(
      int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

String _displayDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/'
    '${d.year}';

// ── Sheet ─────────────────────────────────────────────────────────────────────

class AbsenceFormSheet extends StatefulWidget {
  /// Pass null for create mode; pass existing dto for edit mode.
  final AbsenceDto? initial;
  final Future<void> Function(CreateAbsenceDto) onSave;

  const AbsenceFormSheet({super.key, this.initial, required this.onSave});

  @override
  State<AbsenceFormSheet> createState() => _AbsenceFormSheetState();
}

class _AbsenceFormSheetState extends State<AbsenceFormSheet> {
  DateTime? _startDate;
  DateTime? _endDate;
  int _absenceType = 1;
  final _descCtrl = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      _startDate = _fromApiDate(init.startDate);
      _endDate = _fromApiDate(init.endDate);
      _absenceType = init.absenceType;
      _descCtrl.text = init.description ?? '';
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial =
        isStart ? (_startDate ?? now) : (_endDate ?? _startDate ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        // ensure end >= start
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Informe o período.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(CreateAbsenceDto(
        startDate: _toApiDate(_startDate!),
        endDate: _toApiDate(_endDate!),
        absenceType: _absenceType,
        description:
            _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : AppColors.onDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── drag handle ──────────────────────────────────────────────
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(children: [
                Expanded(
                  child: Text(
                    _isEdit ? 'Editar ausência' : 'Nova ausência',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.onDark : AppColors.slate900,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
            ),

            // ── body ─────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Período
                    Row(children: [
                      Expanded(
                          child: _DatePickerTile(
                        label: 'De',
                        date: _startDate,
                        isDark: isDark,
                        onTap: () => _pickDate(isStart: true),
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _DatePickerTile(
                        label: 'Até',
                        date: _endDate,
                        isDark: isDark,
                        onTap: () => _pickDate(isStart: false),
                      )),
                    ]),

                    const SizedBox(height: 16),

                    // Motivo
                    Text('Motivo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? AppColors.slate300 : AppColors.slate600,
                        )),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 3.2,
                      children: _kAbsenceTypes.map((t) {
                        final selected = _absenceType == t.$1;
                        final isMedical = t.$1 == 2;
                        return GestureDetector(
                          onTap: () => setState(() => _absenceType = t.$1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: selected
                                  ? (isDark
                                      ? AppColors.onDark
                                      : AppColors.slate900)
                                  : (isDark
                                      ? AppColors.slate800
                                      : AppColors.onDark),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? (isDark
                                        ? AppColors.onDark
                                        : AppColors.slate900)
                                    : (isDark
                                        ? AppColors.slate700
                                        : AppColors.slate200),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  t.$3,
                                  size: 15,
                                  color: selected
                                      ? (isDark
                                          ? AppColors.slate900
                                          : AppColors.onDark)
                                      : isMedical
                                          ? AppColors.rose500
                                          : (isDark
                                              ? AppColors.slate400
                                              : AppColors.slate500),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  t.$2,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? (isDark
                                            ? AppColors.slate900
                                            : AppColors.onDark)
                                        : (isDark
                                            ? AppColors.slate300
                                            : AppColors.slate700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Descrição
                    Text('Descrição (opcional)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? AppColors.slate300 : AppColors.slate600,
                        )),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _descCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Ex: Férias em família…',
                        isDense: true,
                        contentPadding: const EdgeInsets.all(12),
                        filled: true,
                        fillColor:
                            isDark ? AppColors.slate800 : AppColors.slate50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: isDark
                                  ? AppColors.slate700
                                  : AppColors.slate200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: isDark
                                  ? AppColors.slate700
                                  : AppColors.slate200),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Actions
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isDark ? AppColors.onDark : AppColors.slate900,
                            foregroundColor:
                                isDark ? AppColors.slate900 : AppColors.onDark,
                            disabledBackgroundColor: isDark
                                ? AppColors.onDark.withAlpha(100)
                                : AppColors.slate400,
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.onDark,
                                  ),
                                )
                              : const Text('Salvar'),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Date tile ─────────────────────────────────────────────────────────────────

class _DatePickerTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final bool isDark;
  final VoidCallback onTap;

  const _DatePickerTile({
    required this.label,
    required this.date,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.slate300 : AppColors.slate600,
            )),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800 : AppColors.slate50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: isDark ? AppColors.slate700 : AppColors.slate200),
            ),
            child: Row(children: [
              Icon(Icons.calendar_today_outlined,
                  size: 14,
                  color: isDark ? AppColors.slate400 : AppColors.slate500),
              const SizedBox(width: 8),
              Text(
                date != null ? _displayDate(date!) : 'Selecionar',
                style: TextStyle(
                  fontSize: 13,
                  color: date != null
                      ? (isDark ? AppColors.onDark : AppColors.slate900)
                      : (isDark ? AppColors.slate500 : AppColors.slate400),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

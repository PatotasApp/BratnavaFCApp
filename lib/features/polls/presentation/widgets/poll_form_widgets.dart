/// Shared form widgets used across poll creation/closing sheets.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

const kPollIcons = [
  '🥩',
  '🍺',
  '🎂',
  '🎉',
  '⚽',
  '🏆',
  '🎵',
  '🍔',
  '🎯',
  '🌟',
  '🤝',
  '🚀',
  '📅',
  '🎊'
];

// ── PollSectionCard ────────────────────────────────────────────────────────────

class PollSectionCard extends StatelessWidget {
  final bool isDark;
  final Widget child;
  const PollSectionCard({super.key, required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate800 : AppColors.slate50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? AppColors.slate700 : AppColors.slate200),
        ),
        child: child,
      );
}

// ── PollDateField ──────────────────────────────────────────────────────────────

class PollDateField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool isDark;
  const PollDateField(
      {super.key,
      required this.label,
      required this.controller,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
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
          controller: controller,
          readOnly: true,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.all(10),
            suffixIcon: Icon(Icons.calendar_today_outlined, size: 16),
          ),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
            );
            if (picked != null) {
              controller.text =
                  '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
            }
          },
        ),
      ],
    );
  }
}

// ── PollTimeField ──────────────────────────────────────────────────────────────

class PollTimeField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool isDark;
  const PollTimeField(
      {super.key,
      required this.label,
      required this.controller,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
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
          controller: controller,
          readOnly: true,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.all(10),
            suffixIcon: Icon(Icons.schedule, size: 16),
          ),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
            );
            if (picked != null) {
              controller.text =
                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
            }
          },
        ),
      ],
    );
  }
}

// ── PollIconPicker ─────────────────────────────────────────────────────────────

class PollIconPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final bool isDark;
  const PollIconPicker(
      {super.key,
      required this.selected,
      required this.onSelect,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ícone (opcional)',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.slate300 : AppColors.slate600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: kPollIcons.map((ic) {
            final active = selected == ic;
            return GestureDetector(
              onTap: () => onSelect(active ? '' : ic),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: active ? AppColors.slate900 : AppColors.transparent,
                    width: 2,
                  ),
                  color: active
                      ? (isDark ? AppColors.slate700 : AppColors.slate100)
                      : AppColors.transparent,
                ),
                alignment: Alignment.center,
                child: Text(ic, style: const TextStyle(fontSize: 20)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── PollCostPicker ─────────────────────────────────────────────────────────────

class PollCostPicker extends StatelessWidget {
  final String selected;
  final TextEditingController amountCtrl;
  final ValueChanged<String> onSelect;
  final bool isDark;

  const PollCostPicker({
    super.key,
    required this.selected,
    required this.amountCtrl,
    required this.onSelect,
    required this.isDark,
  });

  static const _options = [
    ('', 'Sem custo'),
    ('individual', 'Por pessoa'),
    ('group', 'Grupo (rateio)'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Custo (opcional)',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.slate300 : AppColors.slate600)),
        const SizedBox(height: 6),
        Row(
          children: _options.map((opt) {
            final active = selected == opt.$1;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => onSelect(opt.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          active ? AppColors.slate900 : AppColors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              active ? AppColors.slate900 : AppColors.slate200),
                    ),
                    alignment: Alignment.center,
                    child: Text(opt.$2,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: active
                              ? AppColors.onDark
                              : (isDark
                                  ? AppColors.slate300
                                  : AppColors.slate600),
                        )),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.all(10),
              hintText: selected == 'individual'
                  ? 'R\$ por pessoa'
                  : 'R\$ total do grupo',
            ),
          ),
        ],
      ],
    );
  }
}

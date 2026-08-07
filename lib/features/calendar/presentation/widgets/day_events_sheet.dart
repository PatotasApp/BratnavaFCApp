import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/calendar_event.dart';
import 'calendar_utils.dart';

/// Bottom sheet mostrado ao tocar em um dia na visão mensal.
class DayEventsSheet extends StatelessWidget {
  final DateTime day;
  final List<CalendarEvent> events;
  final bool isAdmin;
  final void Function(CalendarEvent) onEventTap;
  final void Function(String date) onNewEvent;

  const DayEventsSheet({
    super.key,
    required this.day,
    required this.events,
    required this.isAdmin,
    required this.onEventTap,
    required this.onNewEvent,
  });

  static Future<void> show(
    BuildContext context, {
    required DateTime day,
    required List<CalendarEvent> events,
    required bool isAdmin,
    required void Function(CalendarEvent) onEventTap,
    required void Function(String) onNewEvent,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => DayEventsSheet(
        day: day,
        events: events,
        isAdmin: isAdmin,
        onEventTap: onEventTap,
        onNewEvent: onNewEvent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ds = toDateStr(day);

    const months = [
      'jan',
      'fev',
      'mar',
      'abr',
      'mai',
      'jun',
      'jul',
      'ago',
      'set',
      'out',
      'nov',
      'dez'
    ];
    const weekdays = [
      'Segunda',
      'Terça',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sábado',
      'Domingo'
    ];
    final title =
        '${weekdays[day.weekday - 1]}, ${day.day} ${months[day.month - 1]}';

    return DraggableScrollableSheet(
      initialChildSize: events.isEmpty ? 0.35 : 0.55,
      minChildSize: 0.25,
      maxChildSize: 0.9,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : AppColors.onDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate700 : AppColors.slate200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Cabeçalho
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.onDark : AppColors.slate900,
                      ),
                    ),
                  ),
                  if (isAdmin)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onNewEvent(ds);
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Novo'),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            isDark ? AppColors.onDark : AppColors.slate900,
                      ),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                    color: isDark ? AppColors.slate500 : AppColors.slate400,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Lista de eventos
            Expanded(
              child: events.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 36,
                            color: isDark
                                ? AppColors.slate700
                                : AppColors.slate200,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Nenhum evento neste dia.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.slate500
                                  : AppColors.slate400,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: events.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final ev = events[i];
                        final c = eventColors(ev);
                        final ic = eventIcon(ev);

                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            onEventTap(ev);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: c.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: c.border),
                            ),
                            child: Row(
                              children: [
                                Text(ic, style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ev.title,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: c.fg,
                                        ),
                                      ),
                                      if (!ev.timeTBD && ev.time != null)
                                        Text(
                                          ev.time!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? AppColors.slate400
                                                : AppColors.slate500,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded,
                                    size: 16,
                                    color: isDark
                                        ? AppColors.slate600
                                        : AppColors.slate400),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

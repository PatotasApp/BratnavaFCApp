import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/calendar_event.dart';
import 'calendar_utils.dart';

class WeekView extends StatelessWidget {
  final DateTime cursor;
  final List<CalendarEvent> events;
  final void Function(CalendarEvent) onEventTap;

  const WeekView({
    super.key,
    required this.cursor,
    required this.events,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = getWeekDays(cursor);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: days.map((day) {
        final ds = toDateStr(day);
        final dayEvs = events.where((e) => e.date == ds).toList();
        final today = isToday(day);

        return Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: isDark ? AppColors.slate800 : AppColors.slate100,
                ),
              ),
            ),
            child: Column(
              children: [
                // ── Cabeçalho do dia ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: today
                        ? (isDark ? AppColors.onDark : AppColors.slate900)
                        : (isDark ? AppColors.slate800 : AppColors.slate50),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? AppColors.slate700 : AppColors.slate200,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _shortWeekday(day),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .8,
                          color: today
                              ? (isDark ? AppColors.slate900 : AppColors.onDark)
                              : (isDark
                                  ? AppColors.slate400
                                  : AppColors.slate500),
                        ),
                      ),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          color: today
                              ? (isDark ? AppColors.slate900 : AppColors.onDark)
                              : (isDark
                                  ? AppColors.onDark
                                  : AppColors.slate900),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Eventos do dia ────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(3),
                    child: Column(
                      children: [
                        if (dayEvs.isEmpty) const SizedBox(height: 40),
                        ...dayEvs.map((ev) => Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: EventPill(
                                ev: ev,
                                onTap: () => onEventTap(ev),
                                compact: true,
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  static String _shortWeekday(DateTime d) {
    const names = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
    return names[d.weekday - 1];
  }
}

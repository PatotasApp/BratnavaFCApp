import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/calendar_event.dart';
import 'calendar_utils.dart';

class DayView extends StatelessWidget {
  final DateTime cursor;
  final List<CalendarEvent> events;
  final bool isAdmin;
  final void Function(CalendarEvent) onEventTap;
  final void Function(String date) onNewEvent;

  const DayView({
    super.key,
    required this.cursor,
    required this.events,
    required this.isAdmin,
    required this.onEventTap,
    required this.onNewEvent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ds = toDateStr(cursor);
    final dayEvs = events.where((e) => e.date == ds).toList();

    if (dayEvs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 40,
              color: isDark ? AppColors.slate700 : AppColors.slate200,
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhum evento neste dia.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.slate500 : AppColors.slate400,
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => onNewEvent(ds),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Criar evento'),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isDark ? AppColors.onDark : AppColors.slate900,
                  foregroundColor:
                      isDark ? AppColors.slate900 : AppColors.onDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: dayEvs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final ev = dayEvs[i];
        final c = eventColors(ev);
        final ic = eventIcon(ev);

        return GestureDetector(
          onTap: () => onEventTap(ev),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ic, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ev.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.fg,
                        ),
                      ),
                      if (!ev.timeTBD &&
                          ev.time != null &&
                          ev.time!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          ev.time!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.slate400
                                : AppColors.slate500,
                          ),
                        ),
                      ],
                      if (ev.description != null &&
                          ev.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          ev.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.slate400
                                : AppColors.slate500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 18,
                    color: isDark ? AppColors.slate600 : AppColors.slate400),
              ],
            ),
          ),
        );
      },
    );
  }

  // _timeLabel removido — horário oculto quando timeTBD ou time == null
}

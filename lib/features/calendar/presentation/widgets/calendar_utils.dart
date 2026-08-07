import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/calendar_event.dart';

// ── Date helpers ──────────────────────────────────────────────────────────────

String toDateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool isToday(DateTime d) => isSameDay(d, DateTime.now());

/// Deslocamento até o domingo anterior (inclusive).
///
/// `DateTime.weekday` é 1=seg…7=dom. O resto por 7 manda o domingo para 0 e
/// mantém seg..sáb em 1..6 — é o que alinha a grade com o protótipo, que abre
/// a semana no domingo.
int sundayOffset(DateTime d) => d.weekday % 7;

/// Gera as semanas do mês (dom→sáb, incluindo dias fora do mês).
List<List<DateTime>> getMonthWeeks(int year, int month) {
  final first = DateTime(year, month, 1);
  final last = DateTime(year, month + 1, 0);

  final start = first.subtract(Duration(days: sundayOffset(first)));

  final weeks = <List<DateTime>>[];
  var cur = start;
  while (cur.isBefore(last) || cur.isAtSameMomentAs(last) || weeks.isEmpty) {
    final week = <DateTime>[];
    for (var i = 0; i < 7; i++) {
      week.add(cur);
      cur = cur.add(const Duration(days: 1));
    }
    weeks.add(week);
    if (cur.isAfter(last) && weeks.length >= 4) break;
  }
  return weeks;
}

/// Retorna os 7 dias da semana (dom→sáb) em que `cursor` está.
List<DateTime> getWeekDays(DateTime cursor) {
  final sunday = cursor.subtract(Duration(days: sundayOffset(cursor)));
  return List.generate(7, (i) => sunday.add(Duration(days: i)));
}

// ── Event style ───────────────────────────────────────────────────────────────

({Color bg, Color fg, Color border}) eventColors(CalendarEvent ev) {
  switch (ev.type) {
    case 'birthday':
      return (
        bg: AppColors.rose50,
        fg: AppColors.prototypeDanger,
        border: AppColors.rose200
      );
    case 'match':
      return ev.isPast
          ? (
              bg: AppColors.slate100,
              fg: AppColors.slate500,
              border: AppColors.slate300
            )
          : (
              bg: AppColors.green100,
              fg: AppColors.primaryPressed,
              border: AppColors.green200
            );
    case 'holiday':
      return (
        bg: AppColors.amber50,
        fg: AppColors.warningLight,
        border: AppColors.amber200
      );
    case 'event':
      return (
        bg: AppColors.violet50,
        fg: AppColors.violet700,
        border: AppColors.violet200
      );
    case 'manual':
      if (ev.categoryColor != null) {
        final hex = ev.categoryColor!.replaceAll('#', '');
        try {
          final base = Color(int.parse('0xFF$hex'));
          return (
            bg: Color.fromARGB(30, (base.r * 255.0).round(),
                (base.g * 255.0).round(), (base.b * 255.0).round()),
            fg: base,
            border: Color.fromARGB(80, (base.r * 255.0).round(),
                (base.g * 255.0).round(), (base.b * 255.0).round()),
          );
        } catch (_) {}
      }
      return (
        bg: AppColors.slate100,
        fg: AppColors.slate700,
        border: AppColors.slate200
      );
    default:
      return (
        bg: AppColors.slate100,
        fg: AppColors.slate700,
        border: AppColors.slate200
      );
  }
}

String eventIcon(CalendarEvent ev) {
  switch (ev.type) {
    case 'birthday':
      return '🎂';
    case 'match':
      return ev.isPast ? '✅' : '⚽';
    case 'holiday':
      return '🎉';
    case 'event':
      return ev.icon ?? '🍖';
    default:
      return ev.icon ?? ev.categoryIcon ?? '📅';
  }
}

Color? dotColor(CalendarEvent ev) {
  final c = eventColors(ev);
  return c.fg.withValues(alpha: .8);
}

// ── EventPill ─────────────────────────────────────────────────────────────────

class EventPill extends StatelessWidget {
  final CalendarEvent ev;
  final VoidCallback onTap;
  final bool compact;

  const EventPill({
    super.key,
    required this.ev,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = eventColors(ev);
    final icon = eventIcon(ev);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: c.border, width: .8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 9)),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                compact
                    ? ev.title
                    : '${!ev.timeTBD && ev.time != null ? "${ev.time} " : ""}${ev.title}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: c.fg,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

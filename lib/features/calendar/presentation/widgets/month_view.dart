import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/calendar_event.dart';
import 'calendar_utils.dart';

/// Grade mensal, espelhando `.proto-calendar-month-grid` do protótipo:
/// células quadradas com cantos de 10, separadas por um respiro de 4, sem
/// bordas de tabela. A contagem de eventos é um badge no canto superior
/// direito — a versão anterior empilhava pills de evento dentro da célula, o
/// que truncava o título em duas ou três letras e não cabia no quadrado.
///
/// O widget encolhe para o tamanho do conteúdo (5 ou 6 semanas conforme o mês),
/// então quem o usa precisa colocá-lo dentro de algo rolável.
class MonthView extends StatelessWidget {
  final DateTime cursor;
  final List<CalendarEvent> events;
  final void Function(DateTime day, List<CalendarEvent> dayEvents) onDayTap;

  /// Dia destacado. A agenda logo abaixo da grade mostra os eventos dele.
  final DateTime? selectedDay;

  /// Iniciais de DOM→SÁB, como no protótipo. Em português três se repetem
  /// (Q de quarta/quinta, S de sexta/sábado); é a posição na linha que
  /// desambigua, então esta ordem não pode mudar sem mexer em `getMonthWeeks`.
  static const _headers = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

  const MonthView({
    super.key,
    required this.cursor,
    required this.events,
    required this.onDayTap,
    this.selectedDay,
  });

  List<CalendarEvent> _eventsForDay(DateTime day) {
    final ds = toDateStr(day);
    return events.where((e) => e.date == ds).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weeks = getMonthWeeks(cursor.year, cursor.month);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Iniciais dos dias da semana ───────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(
            children: _headers
                .map((h) => Expanded(
                      child: Text(
                        h,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color:
                              isDark ? AppColors.slate400 : AppColors.slate500,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),

        // ── Grade de semanas ──────────────────────────────────────────────
        ...weeks.map((week) => Row(
              children: week.map((day) {
                final dayEvs = _eventsForDay(day);
                final selected =
                    selectedDay != null && isSameDay(day, selectedDay!);

                return Expanded(
                  // 2 de cada lado formam o gap de 4 do protótipo.
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _DayCell(
                        day: day,
                        inMonth: day.month == cursor.month,
                        today: isToday(day),
                        selected: selected,
                        dayEvs: dayEvs,
                        isDark: isDark,
                        onTap: () => onDayTap(day, dayEvs),
                      ),
                    ),
                  ),
                );
              }).toList(),
            )),
      ],
    );
  }
}

// ── DayCell ───────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool inMonth;
  final bool today;
  final bool selected;
  final List<CalendarEvent> dayEvs;
  final bool isDark;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.today,
    required this.selected,
    required this.dayEvs,
    required this.isDark,
    required this.onTap,
  });

  /// A célula virou só número + contagem, então o rótulo do leitor de tela
  /// precisa dizer o que o badge significa.
  String get _semanticLabel {
    final n = dayEvs.length;
    if (n == 0) return '${day.day}, sem compromissos';
    return '${day.day}, $n compromisso${n > 1 ? "s" : ""}';
  }

  @override
  Widget build(BuildContext context) {
    final hasEvents = dayEvs.isNotEmpty;
    const accent = AppColors.emerald500;

    // Estados exclusivos, na precedência do protótipo: selecionado > com
    // eventos. `today` só ganha um anel, para não competir com a seleção.
    final Color? fill = selected
        ? accent
        : hasEvents
            ? (isDark ? accent.withValues(alpha: .18) : AppColors.emerald50)
            : null;

    final Color? stroke = selected
        ? accent
        : hasEvents
            ? accent.withValues(alpha: .25)
            : today
                ? (isDark ? AppColors.slate600 : AppColors.slate300)
                : null;

    final Color numberColor = selected
        ? AppColors.onDark
        : !inMonth
            ? (isDark ? AppColors.slate600 : AppColors.slate300)
            : hasEvents
                ? (isDark ? AppColors.emerald200 : AppColors.emerald700)
                : (isDark ? AppColors.slate200 : AppColors.slate700);

    return Semantics(
      button: true,
      selected: selected,
      label: _semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: stroke ?? AppColors.transparent,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: numberColor,
                  ),
                ),
              ),
              if (hasEvents)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 12),
                    height: 12,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.onDark
                          : (isDark ? AppColors.slate900 : AppColors.onDark),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${dayEvs.length}',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

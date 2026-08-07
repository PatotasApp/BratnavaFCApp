import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/confirm_dialog.dart';
import '../../../../shared/presentation/widgets/prototype_ui.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../data/datasources/calendar_remote_datasource.dart';
import '../../domain/entities/calendar_event.dart';
import '../providers/calendar_provider.dart';
import '../widgets/calendar_utils.dart';
import '../widgets/category_manager_sheet.dart';
import '../widgets/create_edit_event_sheet.dart';
import '../widgets/day_view.dart';
import '../widgets/event_detail_sheet.dart';
import '../widgets/month_view.dart';
import '../widgets/week_view.dart';

enum _ViewMode { month, week, day }

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  _ViewMode _view = _ViewMode.month;
  DateTime _cursor = DateTime.now();

  /// Dia destacado na grade mensal, que alimenta a agenda logo abaixo dela.
  /// Separado do `_cursor` de propósito: o cursor anda de mês em mês, o dia
  /// selecionado anda de célula em célula.
  DateTime _selectedDay = DateTime.now();

  List<CalendarEvent> _events = [];
  bool _loading = false;
  String _lastFetchedGroupId = '';

  CalendarRemoteDataSource get _ds => ref.read(calendarDsProvider);

  String get _groupId {
    final acc = ref.read(accountStoreProvider).activeAccount;
    final player = ref.read(activePlayerProvider);
    // O jogador manda no grupo: `activeGroupId` da conta pode apontar
    // para uma patota sem jogador nosso, e aí toda rota por grupo
    // responde 403. Ver dashboard_page para o diagnóstico completo.
    return player?.groupId ?? acc?.activeGroupId ?? '';
  }

  bool get _isAdmin {
    final acc = ref.read(accountStoreProvider).activeAccount;
    if (acc == null) return false;
    final gid = _groupId;
    return acc.isGroupAdmin(gid);
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchEvents());
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _fetchEvents() async {
    final gid = _groupId;
    if (gid.isEmpty) return;
    final range = _rangeForView();
    setState(() => _loading = true);
    try {
      final evs = await _ds.fetchEvents(
          gid, toDateStr(range.start), toDateStr(range.end));
      if (mounted) {
        setState(() {
          _events = evs;
          _loading = false;
          _lastFetchedGroupId = gid;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  ({DateTime start, DateTime end}) _rangeForView() {
    final y = _cursor.year;
    final m = _cursor.month;

    return switch (_view) {
      _ViewMode.month => (
          start: DateTime(y, m, 1),
          end: DateTime(y, m + 1, 0),
        ),
      _ViewMode.week => () {
          final sun = _cursor.subtract(Duration(days: sundayOffset(_cursor)));
          return (start: sun, end: sun.add(const Duration(days: 6)));
        }(),
      _ViewMode.day => (start: _cursor, end: _cursor),
    };
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _prev() {
    setState(() {
      _cursor = switch (_view) {
        _ViewMode.month => DateTime(_cursor.year, _cursor.month - 1),
        _ViewMode.week => _cursor.subtract(const Duration(days: 7)),
        _ViewMode.day => _cursor.subtract(const Duration(days: 1)),
      };
      _syncSelectedDay();
    });
    _fetchEvents();
  }

  void _next() {
    setState(() {
      _cursor = switch (_view) {
        _ViewMode.month => DateTime(_cursor.year, _cursor.month + 1),
        _ViewMode.week => _cursor.add(const Duration(days: 7)),
        _ViewMode.day => _cursor.add(const Duration(days: 1)),
      };
      _syncSelectedDay();
    });
    _fetchEvents();
  }

  void _goToday() {
    setState(() {
      _cursor = DateTime.now();
      _selectedDay = DateTime.now();
    });
    _fetchEvents();
  }

  /// Ao trocar de período, o dia destacado precisa acompanhar — senão a agenda
  /// continuaria mostrando um dia que não está mais visível na grade.
  void _syncSelectedDay() {
    if (isSameDay(_selectedDay, _cursor)) return;
    if (_selectedDay.year == _cursor.year &&
        _selectedDay.month == _cursor.month) {
      return;
    }
    _selectedDay = _cursor;
  }

  void _setView(_ViewMode v) {
    if (_view == v) return;
    setState(() => _view = v);
    _fetchEvents();
  }

  // ── Event actions ─────────────────────────────────────────────────────────

  void _openEvent(BuildContext ctx, CalendarEvent ev) {
    EventDetailSheet.show(
      ctx,
      ev: ev,
      isAdmin: _isAdmin,
      onEdit: () {
        Navigator.pop(ctx);
        _openCreateEdit(ctx, event: ev);
      },
      onDelete: () async {
        Navigator.pop(ctx);
        await _deleteEvent(ev);
      },
    );
  }

  void _openCreateEdit(BuildContext ctx, {CalendarEvent? event, String? date}) {
    final cats =
        ref.read(calendarCategoriesProvider(_groupId)).valueOrNull ?? [];
    CreateEditEventSheet.show(
      ctx,
      groupId: _groupId,
      datasource: _ds,
      categories: cats,
      event: event,
      initialDate: date,
      onSaved: _fetchEvents,
    );
  }

  Future<void> _deleteEvent(CalendarEvent ev) async {
    if (ev.id == null) return;
    final ok = await showConfirmDialog(
      context: context,
      title: 'Excluir evento',
      message: 'Excluir "${ev.title}"?',
      confirmLabel: 'Excluir',
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await _ds.deleteEvent(_groupId, ev.id!);
      _fetchEvents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e')),
        );
      }
    }
  }

  /// Eventos de um dia, a partir do que já foi buscado para o período.
  List<CalendarEvent> _eventsOn(DateTime day) {
    final ds = toDateStr(day);
    return _events.where((e) => e.date == ds).toList();
  }

  void _openCategories(BuildContext ctx) {
    final cats =
        ref.read(calendarCategoriesProvider(_groupId)).valueOrNull ?? [];
    CategoryManagerSheet.show(
      ctx,
      groupId: _groupId,
      datasource: _ds,
      categories: cats,
      onChanged: () => ref.invalidate(calendarCategoriesProvider(_groupId)),
    );
  }

  // ── Title helpers ─────────────────────────────────────────────────────────

  String get _title {
    return switch (_view) {
      _ViewMode.month => _monthTitle(),
      _ViewMode.week => _weekTitle(),
      _ViewMode.day => _dayTitle(),
    };
  }

  String _monthTitle() {
    const months = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro'
    ];
    return '${months[_cursor.month - 1]} ${_cursor.year}';
  }

  String _weekTitle() {
    // `mon`/`sun` viraram início/fim da semana — a semana agora abre no domingo.
    final mon = _cursor.subtract(Duration(days: sundayOffset(_cursor)));
    final sun = mon.add(const Duration(days: 6));
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
    if (mon.month == sun.month) {
      return '${mon.day}–${sun.day} ${months[mon.month - 1]} ${mon.year}';
    }
    return '${mon.day} ${months[mon.month - 1]} – ${sun.day} ${months[sun.month - 1]} ${sun.year}';
  }

  String _dayTitle() {
    const weekdays = [
      'Segunda',
      'Terça',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sábado',
      'Domingo'
    ];
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
    return '${weekdays[_cursor.weekday - 1]}, ${_cursor.day} ${months[_cursor.month - 1]}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final account = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    final resolvedId = activePlayer?.groupId ?? account?.activeGroupId ?? '';

    // Re-busca quando o grupo resolve (bootstrap async) ou troca de conta.
    if (resolvedId.isNotEmpty &&
        resolvedId != _lastFetchedGroupId &&
        !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _events = []);
          _fetchEvents();
        }
      });
    }

    if (resolvedId.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 44,
                  color: isDark ? AppColors.slate700 : AppColors.slate200),
              const SizedBox(height: 12),
              Text('Crie ou entre em um grupo',
                  style: TextStyle(
                      color: isDark ? AppColors.slate500 : AppColors.slate400)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          // ── Header gradiente ─────────────────────────────────────────────
          _CalendarHeader(
            title: _title,
            loading: _loading,
            view: _view,
            isAdmin: _isAdmin,
            onPrev: _prev,
            onNext: _next,
            onToday: _goToday,
            onView: _setView,
            onNew: () => _openCreateEdit(context),
            onCategories: () => _openCategories(context),
          ),

          // ── Corpo do calendário ──────────────────────────────────────────
          Expanded(
            child: switch (_view) {
              // A grade encolhe para o tamanho do mês (5 ou 6 semanas) e a
              // agenda do dia vem logo abaixo, como no protótipo. Tocar num
              // dia seleciona; a folha de detalhes agora sai do card, não da
              // célula — na célula só cabia o número.
              _ViewMode.month => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MonthView(
                        cursor: _cursor,
                        events: _events,
                        selectedDay: _selectedDay,
                        onDayTap: (day, _) =>
                            setState(() => _selectedDay = day),
                      ),
                      const SizedBox(height: 14),
                      _DayAgendaCard(
                        day: _selectedDay,
                        events: _eventsOn(_selectedDay),
                        canCreate: _isAdmin,
                        onEventTap: (ev) => _openEvent(context, ev),
                        onNew: () => _openCreateEdit(
                          context,
                          date: toDateStr(_selectedDay),
                        ),
                      ),
                    ],
                  ),
                ),
              _ViewMode.week => WeekView(
                  cursor: _cursor,
                  events: _events,
                  onEventTap: (ev) => _openEvent(context, ev),
                ),
              _ViewMode.day => DayView(
                  cursor: _cursor,
                  events: _events,
                  isAdmin: _isAdmin,
                  onEventTap: (ev) => _openEvent(context, ev),
                  onNewEvent: (date) => _openCreateEdit(context, date: date),
                ),
            },
          ),
        ],
      ),
    );
  }
}

// ── Header gradiente ──────────────────────────────────────────────────────────

class _CalendarHeader extends StatelessWidget {
  final String title;
  final bool loading;
  final _ViewMode view;
  final bool isAdmin;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final void Function(_ViewMode) onView;
  final VoidCallback onNew;
  final VoidCallback onCategories;

  const _CalendarHeader({
    required this.title,
    required this.loading,
    required this.view,
    required this.isAdmin,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onView,
    required this.onNew,
    required this.onCategories,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.lightText,
            AppColors.darkCard,
            AppColors.lightText
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              // Row 1: ícone + título + ações admin
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/app');
                      }
                    },
                    tooltip: 'Voltar',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.onDark.withAlpha(20),
                      foregroundColor: AppColors.onDark,
                      side: BorderSide(color: AppColors.onDark.withAlpha(40)),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.onDark.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.onDark.withValues(alpha: .2)),
                    ),
                    child: const Icon(Icons.calendar_month_rounded,
                        size: 20, color: AppColors.onDark),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Calendário',
                            style: TextStyle(
                              color: AppColors.onDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            )),
                        loading
                            ? Row(children: [
                                const SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: AppColors.onDark54,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text('Carregando...',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.onDark
                                            .withValues(alpha: .5))),
                              ])
                            : Text(
                                title,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.onDark.withValues(alpha: .5),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                      ],
                    ),
                  ),
                  if (isAdmin) ...[
                    // Categorias
                    _HdrBtn(
                      icon: Icons.tune_rounded,
                      onTap: onCategories,
                      tooltip: 'Categorias',
                    ),
                    const SizedBox(width: 6),
                    // Novo evento
                    GestureDetector(
                      onTap: onNew,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.onDark,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add,
                                size: 14, color: AppColors.lightText),
                            SizedBox(width: 4),
                            Text('Evento',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.lightText,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 12),

              // Row 2: prev/next + hoje + view toggle
              Row(
                children: [
                  // Prev
                  _HdrBtn(icon: Icons.chevron_left_rounded, onTap: onPrev),
                  const SizedBox(width: 6),
                  // Next
                  _HdrBtn(icon: Icons.chevron_right_rounded, onTap: onNext),
                  const SizedBox(width: 6),
                  // Hoje
                  GestureDetector(
                    onTap: onToday,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.onDark.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.onDark.withValues(alpha: .2)),
                      ),
                      child: Text('Hoje',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onDark.withValues(alpha: .9),
                          )),
                    ),
                  ),
                  const Spacer(),
                  // View toggle
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.onDark.withValues(alpha: .2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Ordem e nomes seguem o Segmented do protótipo:
                        // "Diário · Semanal · Mensal", do menor período ao maior.
                        _ViewBtn(
                            label: 'Diário',
                            mode: _ViewMode.day,
                            current: view,
                            onTap: onView),
                        _ViewBtn(
                            label: 'Semanal',
                            mode: _ViewMode.week,
                            current: view,
                            onTap: onView),
                        _ViewBtn(
                            label: 'Mensal',
                            mode: _ViewMode.month,
                            current: view,
                            onTap: onView),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HdrBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _HdrBtn({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.onDark.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.onDark.withValues(alpha: .2)),
          ),
          child: Icon(icon, size: 18, color: AppColors.onDark),
        ),
      ),
    );
  }
}

class _ViewBtn extends StatelessWidget {
  final String label;
  final _ViewMode mode;
  final _ViewMode current;
  final void Function(_ViewMode) onTap;

  const _ViewBtn({
    required this.label,
    required this.mode,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = mode == current;
    return GestureDetector(
      onTap: () => onTap(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.onDark : AppColors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected
                ? AppColors.lightText
                : AppColors.onDark.withValues(alpha: .8),
          ),
        ),
      ),
    );
  }
}

// ── Agenda do dia selecionado ─────────────────────────────────────────────────

/// Card que o protótipo mostra logo abaixo da grade mensal: título "{dia} de
/// {mês}", a contagem, e os compromissos daquele dia — ou um estado vazio.
/// O app não tinha esse card; tocar num dia só abria uma bottom sheet, então a
/// agenda do dia nunca ficava visível junto com o mês.
class _DayAgendaCard extends StatelessWidget {
  final DateTime day;
  final List<CalendarEvent> events;
  final bool canCreate;
  final void Function(CalendarEvent ev) onEventTap;
  final VoidCallback onNew;

  const _DayAgendaCard({
    required this.day,
    required this.events,
    required this.canCreate,
    required this.onEventTap,
    required this.onNew,
  });

  static const _months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : AppColors.onDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.slate800 : AppColors.slate200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrototypeSectionTitle(
            title: '${day.day} de ${_months[day.month - 1]}',
            count: events.isEmpty ? null : '${events.length}',
            actionLabel: canCreate ? 'Adicionar' : null,
            onAction: canCreate ? onNew : null,
          ),
          const SizedBox(height: 10),
          if (events.isEmpty)
            _EmptyDay(isDark: isDark)
          else
            ...events.map((ev) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AgendaRow(
                    ev: ev,
                    isDark: isDark,
                    onTap: () => onEventTap(ev),
                  ),
                )),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  final bool isDark;
  const _EmptyDay({required this.isDark});

  @override
  Widget build(BuildContext context) {
    // `.proto-calendar-empty`: 82 de altura, ícone sobre o texto, tudo centrado.
    final muted = isDark ? AppColors.slate400 : AppColors.slate500;
    return SizedBox(
      height: 82,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_outlined, size: 22, color: muted),
          const SizedBox(height: 7),
          Text(
            'Nenhum compromisso neste dia',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: muted),
          ),
        ],
      ),
    );
  }
}

/// Linha de compromisso, seguindo `.proto-calendar-event`: quadrado de ícone
/// de 34, título de 11 e subtítulo de 9, altura mínima de 58.
class _AgendaRow extends StatelessWidget {
  final CalendarEvent ev;
  final bool isDark;
  final VoidCallback onTap;

  const _AgendaRow({
    required this.ev,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = eventColors(ev);
    // `CalendarEvent` não tem campo de local; o subtítulo do protótipo vira
    // aqui hora + categoria (ou a descrição, quando não há categoria).
    final detail = (ev.categoryName?.isNotEmpty ?? false)
        ? ev.categoryName!
        : (ev.description ?? '');
    final subtitle = [
      if (!ev.timeTBD && ev.time != null && ev.time!.isNotEmpty) ev.time!,
      if (ev.timeTBD) 'horário a definir',
      if (detail.isNotEmpty) detail,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate800 : AppColors.slate50,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: isDark ? AppColors.slate700 : AppColors.slate200,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: c.border),
              ),
              child: Text(eventIcon(ev), style: const TextStyle(fontSize: 17)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ev.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.onDark : AppColors.slate900,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.slate400 : AppColors.slate500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

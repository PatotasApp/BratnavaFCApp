import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/confirm_dialog.dart';
import '../../../../shared/presentation/widgets/prototype_ui.dart';
import '../../../../shared/presentation/widgets/app_page_header.dart';
import '../../../../shared/presentation/widgets/no_active_group_view.dart';
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
    return acc?.activeGroupId ?? player?.groupId ?? '';
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

  Future<void> _openCreateEdit(BuildContext ctx,
      {CalendarEvent? event, String? date}) async {
    // Garante que as categorias estejam carregadas ANTES de abrir o sheet.
    // Antes vinha de `.valueOrNull` (nulo enquanto o provider não resolvia), e
    // a seção "Categoria" some quando a lista está vazia — por isso as
    // categorias "só apareciam depois de criar uma nova".
    List<CalendarCategory> cats;
    try {
      cats = await ref.read(calendarCategoriesProvider(_groupId).future);
    } catch (_) {
      cats = ref.read(calendarCategoriesProvider(_groupId)).valueOrNull ?? [];
    }
    if (!mounted) return;
    CreateEditEventSheet.show(
      context,
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

  Future<void> _openCategories(BuildContext ctx) async {
    List<CalendarCategory> cats;
    try {
      cats = await ref.read(calendarCategoriesProvider(_groupId).future);
    } catch (_) {
      cats = ref.read(calendarCategoriesProvider(_groupId)).valueOrNull ?? [];
    }
    if (!mounted) return;
    CategoryManagerSheet.show(
      context,
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
    final account = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    final resolvedId = account?.activeGroupId ?? activePlayer?.groupId ?? '';

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
      return const Scaffold(
        body: Column(
          children: [
            AppPageHeader.main(
              title: 'Calendário',
              icon: Icons.calendar_month_outlined,
            ),
            Expanded(
              child: NoActiveGroupView(
                message: 'Selecione uma patota para ver o calendário.',
              ),
            ),
          ],
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
    return AppPageHeader(
      title: 'Calendário',
      subtitle: loading ? 'Carregando calendário...' : title,
      icon: Icons.calendar_month_rounded,
      footer: Column(
        children: [
          if (isAdmin) ...[
            AppPageHeaderActionBar(
              actions: [
                AppPageHeaderButton(
                  label: 'Categorias',
                  icon: Icons.tune_rounded,
                  onPressed: onCategories,
                ),
                AppPageHeaderButton(
                  label: 'Novo evento',
                  icon: Icons.add_rounded,
                  tone: AppPageHeaderButtonTone.primary,
                  onPressed: onNew,
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              IconButton(
                tooltip: 'Período anterior',
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                tooltip: 'Próximo período',
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              TextButton(onPressed: onToday, child: const Text('Hoje')),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<_ViewMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _ViewMode.day, label: Text('Diário')),
                ButtonSegment(value: _ViewMode.week, label: Text('Semanal')),
                ButtonSegment(value: _ViewMode.month, label: Text('Mensal')),
              ],
              selected: {view},
              onSelectionChanged: (selection) => onView(selection.first),
            ),
          ),
        ],
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

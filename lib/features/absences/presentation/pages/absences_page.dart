import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../../../shared/presentation/widgets/confirm_dialog.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../data/datasources/absences_remote_datasource.dart';
import '../../domain/entities/absence.dart';
import '../providers/absences_provider.dart';
import '../widgets/absence_form_sheet.dart';

const _pageSize = 20;
const _monthLabels = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

String _formatDate(String d) {
  final parts = d.split('-');
  if (parts.length != 3) return d;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

String _monthLabel(String iso) {
  final parts = iso.split('-');
  if (parts.length < 2) return iso;
  final month = int.tryParse(parts[1]) ?? 1;
  final index = (month - 1).clamp(0, 11);
  return '${_monthLabels[index]} ${parts[0]}';
}

String _todayIso() {
  final d = DateTime.now();
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

IconData _absenceIcon(int type) {
  switch (type) {
    case 1:
      return Icons.flight_outlined;
    case 2:
      return Icons.local_hospital_outlined;
    case 3:
      return Icons.favorite_border;
    default:
      return Icons.more_horiz_outlined;
  }
}

class AbsencesPage extends ConsumerStatefulWidget {
  const AbsencesPage({super.key});

  @override
  ConsumerState<AbsencesPage> createState() => _AbsencesPageState();
}

class _AbsencesPageState extends ConsumerState<AbsencesPage> {
  PagedAbsences _upcoming = PagedAbsences.empty;
  PagedAbsences _past = PagedAbsences.empty;
  String? _loadedGroupId;
  bool _loading = false;
  bool _loadingMore = false;
  bool _loadingPast = false;
  bool _pastLoaded = false;
  bool _showPast = true;
  String? _error;

  AbsencesRemoteDataSource get _ds => ref.read(absencesDsProvider);

  Future<void> _loadForGroup(String groupId) async {
    setState(() {
      _loadedGroupId = groupId;
      _loading = true;
      _error = null;
      _upcoming = PagedAbsences.empty;
      _past = PagedAbsences.empty;
      _pastLoaded = false;
    });

    try {
      final upcoming = await _ds.fetchByGroup(
        groupId,
        status: 'upcoming',
        page: 1,
        pageSize: _pageSize,
      );
      PagedAbsences past = PagedAbsences.empty;
      if (_showPast) {
        past = await _ds.fetchByGroup(
          groupId,
          status: 'past',
          page: 1,
          pageSize: _pageSize,
        );
      }
      if (!mounted) return;
      setState(() {
        _upcoming = upcoming;
        _past = past;
        _pastLoaded = _showPast;
      });
    } catch (e) {
      if (!mounted) return;
      setState(
          () => _error = extractDioError(e, 'Erro ao carregar ausências.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh(String groupId) => _loadForGroup(groupId);

  Future<void> _loadMoreUpcoming(String groupId) async {
    if (_loadingMore || _upcoming.items.length >= _upcoming.total) return;
    setState(() => _loadingMore = true);
    try {
      final next = await _ds.fetchByGroup(
        groupId,
        status: 'upcoming',
        page: _upcoming.page + 1,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _upcoming = PagedAbsences(
          items: [..._upcoming.items, ...next.items],
          total: next.total,
          page: next.page,
        );
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadPast(String groupId, {bool append = false}) async {
    if (_loadingPast) return;
    setState(() => _loadingPast = true);
    try {
      final next = await _ds.fetchByGroup(
        groupId,
        status: 'past',
        page: append ? _past.page + 1 : 1,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _past = append
            ? PagedAbsences(
                items: [..._past.items, ...next.items],
                total: next.total,
                page: next.page,
              )
            : next;
        _pastLoaded = true;
      });
    } finally {
      if (mounted) setState(() => _loadingPast = false);
    }
  }

  Future<void> _togglePast(String groupId) async {
    final next = !_showPast;
    setState(() => _showPast = next);
    if (next && !_pastLoaded) await _loadPast(groupId);
  }

  Future<void> _openCreate(String groupId) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => AbsenceFormSheet(
        onSave: (dto) async {
          await _ds.create(dto);
          if (mounted) Navigator.of(context).pop();
          await _refresh(groupId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ausência cadastrada.')),
            );
          }
        },
      ),
    );
  }

  Future<void> _openEdit(String groupId, AbsenceDto absence) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => AbsenceFormSheet(
        initial: absence,
        onSave: (dto) async {
          await _ds.update(absence.id, dto);
          if (mounted) Navigator.of(context).pop();
          await _refresh(groupId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ausência atualizada.')),
            );
          }
        },
      ),
    );
  }

  Future<void> _delete(String groupId, AbsenceDto absence) async {
    final confirm = await showConfirmDialog(
      context: context,
      title: 'Excluir ausência',
      message:
          'Deseja excluir esta ausência? Os convites recusados automaticamente por ela voltarão a ficar pendentes.',
      confirmLabel: 'Excluir',
      danger: true,
    );
    if (!confirm) return;
    try {
      await _ds.delete(absence.id);
      await _refresh(groupId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ausência removida.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(extractDioError(e, 'Erro ao remover ausência.'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    // O jogador manda no grupo: `activeGroupId` da conta pode apontar
    // para uma patota sem jogador nosso, e aí toda rota por grupo
    // responde 403. Ver dashboard_page para o diagnóstico completo.
    final groupId = activePlayer?.groupId ?? account?.activeGroupId ?? '';
    final activePlayerId =
        account?.activePlayerId ?? activePlayer?.playerId ?? '';

    if (groupId.isNotEmpty && _loadedGroupId != groupId && !_loading) {
      Future.microtask(() => _loadForGroup(groupId));
    }

    final today = _todayIso();
    final ongoing = _upcoming.items
        .where((a) => a.startDate.compareTo(today) <= 0)
        .toList();
    final upcoming =
        _upcoming.items.where((a) => a.startDate.compareTo(today) > 0).toList();
    final groupedUpcoming = _groupByMonth(upcoming);

    // Rota do shell sem AppBar: precisa respeitar o inset da status bar.
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: groupId.isEmpty
              ? () async {}
              : () async {
                  await _refresh(groupId);
                },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                  child: _Header(
                    loading: _loading,
                    total: _upcoming.total,
                    onAddTap:
                        groupId.isEmpty ? null : () => _openCreate(groupId),
                  ),
                ),
              ),
              if (groupId.isEmpty)
                const SliverToBoxAdapter(
                  child: _InfoState(
                      message: 'Selecione uma patota para ver ausências.'),
                )
              else if (_loading)
                const SliverToBoxAdapter(child: _SkeletonList())
              else if (_error != null)
                SliverToBoxAdapter(child: _InfoState(message: _error!))
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_upcoming.items.isEmpty)
                          const _EmptyState()
                        else ...[
                          if (ongoing.isNotEmpty) ...[
                            _SectionTitle(
                              label: 'Fora agora',
                              count: ongoing.length,
                              active: true,
                            ),
                            const SizedBox(height: 8),
                            ...ongoing.map(
                              (a) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _AbsenceCard(
                                  groupId: groupId,
                                  absence: a,
                                  active: true,
                                  isSelf: a.playerId == activePlayerId,
                                  onEdit: () => _openEdit(groupId, a),
                                  onDelete: () => _delete(groupId, a),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          ...groupedUpcoming.map((group) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _SectionTitle(label: group.label),
                                  const SizedBox(height: 8),
                                  ...group.items.map(
                                    (a) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _AbsenceCard(
                                        groupId: groupId,
                                        absence: a,
                                        active: false,
                                        isSelf: a.playerId == activePlayerId,
                                        onEdit: () => _openEdit(groupId, a),
                                        onDelete: () => _delete(groupId, a),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          _LoadMoreButton(
                            loaded: _upcoming.items.length,
                            total: _upcoming.total,
                            loading: _loadingMore,
                            onTap: () => _loadMoreUpcoming(groupId),
                          ),
                        ],
                        // O protótipo simplesmente não desenha a seção quando ela
                        // está vazia. Aqui a contagem só chega depois do
                        // carregamento preguiçoso, então mantemos o cabeçalho
                        // enquanto não se sabe e o removemos quando volta zero —
                        // em vez de deixar "ENCERRADAS · 0" ocupando espaço.
                        if (!_pastLoaded || _past.total > 0) ...[
                          const SizedBox(height: 4),
                          _PastHeader(
                            total: _pastLoaded ? _past.total : null,
                            expanded: _showPast,
                            loading: _loadingPast && !_pastLoaded,
                            onTap: () => _togglePast(groupId),
                          ),
                          if (_showPast) ...[
                            const SizedBox(height: 8),
                            if (_loadingPast && !_pastLoaded)
                              const _SkeletonList(compact: true)
                            else ...[
                              Opacity(
                                opacity: 0.62,
                                child: Column(
                                  children: _past.items
                                      .map(
                                        (a) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 8),
                                          child: _AbsenceCard(
                                            groupId: groupId,
                                            absence: a,
                                            active: false,
                                            isSelf:
                                                a.playerId == activePlayerId,
                                            onEdit: () => _openEdit(groupId, a),
                                            onDelete: () => _delete(groupId, a),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                              _LoadMoreButton(
                                loaded: _past.items.length,
                                total: _past.total,
                                loading: _loadingPast,
                                onTap: () => _loadPast(groupId, append: true),
                              ),
                            ],
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<_AbsenceMonthGroup> _groupByMonth(List<AbsenceDto> absences) {
    final groups = <_AbsenceMonthGroup>[];
    for (final absence in absences) {
      final label = _monthLabel(absence.startDate);
      if (groups.isNotEmpty && groups.last.label == label) {
        groups.last.items.add(absence);
      } else {
        groups.add(_AbsenceMonthGroup(label, [absence]));
      }
    }
    return groups;
  }
}

class _AbsenceMonthGroup {
  final String label;
  final List<AbsenceDto> items;
  _AbsenceMonthGroup(this.label, this.items);
}

class _Header extends StatelessWidget {
  final bool loading;
  final int total;
  final VoidCallback? onAddTap;

  const _Header({
    required this.loading,
    required this.total,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = loading
        ? 'Carregando...'
        : '$total ausência${total != 1 ? 's' : ''} ativa${total != 1 ? 's' : ''} ou futura${total != 1 ? 's' : ''}';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.slate900,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _HeaderDotsPainter())),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.onDark.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: AppColors.onDark.withAlpha(36)),
                      ),
                      child: const Icon(
                        Icons.event_busy_outlined,
                        color: AppColors.onDark,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ausências',
                            style: TextStyle(
                              color: AppColors.onDark,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: AppColors.onDark60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onAddTap,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nova ausência'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.onDark,
                    foregroundColor: AppColors.slate900,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.onDark.withAlpha(12);
    for (var x = 0.0; x < size.width; x += 22) {
      for (var y = 0.0; y < size.height; y += 22) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SectionTitle extends StatelessWidget {
  final String label;
  final int? count;
  final bool active;

  const _SectionTitle({
    required this.label,
    this.count,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (active) ...[
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.rose400,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          '${label.toUpperCase()}${count != null ? ' · $count' : ''}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            color: AppColors.slate500,
          ),
        ),
      ],
    );
  }
}

class _PastHeader extends StatelessWidget {
  final int? total;
  final bool expanded;
  final bool loading;
  final VoidCallback onTap;

  const _PastHeader({
    required this.total,
    required this.expanded,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(
              'ENCERRADAS${total != null ? ' · $total' : ''}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
                color: AppColors.slate500,
              ),
            ),
            const SizedBox(width: 4),
            if (loading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              )
            else
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppColors.slate400,
              ),
          ],
        ),
      ),
    );
  }
}

class _AbsenceCard extends StatelessWidget {
  final String groupId;
  final AbsenceDto absence;
  final bool active;
  final bool isSelf;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AbsenceCard({
    required this.groupId,
    required this.absence,
    required this.active,
    required this.isSelf,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isMedical = absence.absenceType == 2;
    final dateLabel = absence.startDate == absence.endDate
        ? _formatDate(absence.startDate)
        : '${_formatDate(absence.startDate)} até ${_formatDate(absence.endDate)}';
    final playerName = (absence.playerName?.trim().isNotEmpty ?? false)
        ? absence.playerName!.trim()
        : 'Você';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.onDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? AppColors.rose200 : AppColors.slate200,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate200.withAlpha(80),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isMedical ? AppColors.rose50 : AppColors.slate100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _absenceIcon(absence.absenceType),
              size: 18,
              color: isMedical ? AppColors.rose500 : AppColors.slate500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: ConfiguredPlayerName(
                        groupId: groupId,
                        name: playerName,
                        isGoalkeeper: absence.isGoalkeeper,
                        iconSize: 13,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate900,
                        ),
                      ),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.slate100,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'você',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slate500,
                          ),
                        ),
                      ),
                    ],
                    // O protótipo marca a ausência em curso com um badge
                    // vermelho na própria linha. A borda rosa do card sozinha
                    // não diz que está ativa *agora* — some no meio da lista.
                    if (active) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.rose50,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.rose200),
                        ),
                        child: const Text(
                          'Ativa',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.rose600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                // Duas linhas: "Viagem · 17/07/2026 até 31/07/2026" não cabe
                // em uma só ao lado do ícone de 40, e cortar a data final
                // ("até 31/07/2…") esconde justamente a informação que importa.
                Text(
                  '${absence.absenceTypeName} · $dateLabel',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.slate500,
                  ),
                ),
                if ((absence.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    absence.description!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isSelf) ...[
            const SizedBox(width: 8),
            _ActionButton(
              icon: Icons.edit_outlined,
              onTap: onEdit,
              danger: false,
            ),
            const SizedBox(width: 6),
            _ActionButton(
              icon: Icons.delete_outline,
              onTap: onDelete,
              danger: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  const _ActionButton({
    required this.icon,
    required this.onTap,
    required this.danger,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: danger ? AppColors.rose200 : AppColors.slate200,
          ),
        ),
        child: Icon(
          icon,
          size: 15,
          color: danger ? AppColors.rose500 : AppColors.slate500,
        ),
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  final int loaded;
  final int total;
  final bool loading;
  final VoidCallback onTap;

  const _LoadMoreButton({
    required this.loaded,
    required this.total,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (loaded >= total) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: OutlinedButton(
        onPressed: loading ? null : onTap,
        child: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text('Carregar mais ($loaded/$total)'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.onDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate200),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_busy_outlined,
            size: 36,
            color: AppColors.slate300,
          ),
          SizedBox(height: 12),
          Text(
            'Nenhuma ausência ativa ou futura.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoState extends StatelessWidget {
  final String message;
  const _InfoState({required this.message});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.slate500),
          ),
        ),
      );
}

class _SkeletonList extends StatelessWidget {
  final bool compact;
  const _SkeletonList({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, compact ? 0 : 16, 24, 0),
      child: Column(
        children: [
          for (var i = 0; i < (compact ? 2 : 5); i++) ...[
            Container(
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

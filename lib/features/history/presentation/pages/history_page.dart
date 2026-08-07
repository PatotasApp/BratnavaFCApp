import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/prototype_ui.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../domain/entities/history_match.dart';
import '../providers/history_provider.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  int _visibleCount = 5;
  bool _onlyMine = false;
  final _scrollController = ScrollController();

  void _setOnlyMine(bool value) {
    setState(() {
      _onlyMine = value;
      _visibleCount = 5;
    });
  }

  Future<void> _refresh(String? groupId) async {
    if (groupId == null || groupId.isEmpty) return;
    ref.invalidate(historyPageProvider);
    setState(() => _visibleCount = 5);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    // O jogador manda no grupo: `activeGroupId` da conta pode apontar
    // para uma patota sem jogador nosso, e aí toda rota por grupo
    // responde 403. Ver dashboard_page para o diagnóstico completo.
    final groupId = activePlayer?.groupId ?? account?.activeGroupId;
    final playerId = account?.activePlayerId ?? activePlayer?.playerId;
    final filterPlayerId = _onlyMine ? playerId : null;

    final historyAsync = groupId == null || groupId.isEmpty
        ? null
        : ref.watch(
            historyPageProvider(
              (
                groupId: groupId,
                page: 1,
                pageSize: _visibleCount,
                playerId: filterPlayerId,
              ),
            ),
          );

    return RefreshIndicator(
      onRefresh: () => _refresh(groupId),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _HistoryHeader(
              total: historyAsync?.valueOrNull?.total,
              loading: historyAsync?.isLoading ?? false,
              onRefresh: groupId == null ? null : () => _refresh(groupId),
            ),
          ),
          if (playerId != null)
            SliverToBoxAdapter(
              child: _HistoryFilter(
                onlyMine: _onlyMine,
                onChanged: _setOnlyMine,
              ),
            ),
          if (historyAsync == null)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _NoGroupState(),
            )
          else
            historyAsync.when(
              loading: () => const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
                sliver: SliverToBoxAdapter(child: _HistorySkeletons()),
              ),
              error: (error, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: _HistoryError(
                  error: error,
                  onRetry: () => _refresh(groupId),
                ),
              ),
              data: (pageData) {
                final matches = [...pageData.items]..sort((a, b) {
                    final aDate = a.playedAt?.millisecondsSinceEpoch ?? 0;
                    final bDate = b.playedAt?.millisecondsSinceEpoch ?? 0;
                    return bDate.compareTo(aDate);
                  });

                final finalized = matches.where((match) {
                  final status = match.statusName?.trim().toLowerCase() ?? '';
                  return status.isEmpty ||
                      status.contains('final') ||
                      status == 'done';
                }).toList();

                if (finalized.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _HistoryEmpty(onlyMine: _onlyMine),
                  );
                }

                final canLoadMore = _visibleCount < pageData.total;
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  sliver: SliverList.list(
                    children: [
                      for (final match in finalized) ...[
                        _HistoryMatchCard(
                          match: match,
                          onTap: () => context.go(
                            '/app/history/${match.groupId}/${match.id}',
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (canLoadMore) ...[
                        const SizedBox(height: 4),
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _visibleCount += 5),
                          icon: const Icon(Icons.expand_more_rounded),
                          label: Text(
                            'Carregar mais '
                            '(${pageData.total - _visibleCount})',
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  final int? total;
  final bool loading;
  final VoidCallback? onRefresh;

  const _HistoryHeader({
    required this.total,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = loading
        ? 'Carregando partidas'
        : total == null
            ? 'Histórico da patota'
            : '$total partida${total == 1 ? '' : 's'}';

    // O shell só coloca AppBar na aba Dashboard; as demais desenham a partir do
    // topo absoluto. Sem somar o inset o conteúdo fica sob a status bar.
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      height: 72 + topInset,
      padding: EdgeInsets.fromLTRB(16, 12 + topInset, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          const PrototypeIconBox(icon: Icon(Icons.history_rounded)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Histórico', style: theme.textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (onRefresh != null)
            IconButton(
              tooltip: 'Atualizar',
              onPressed: loading ? null : onRefresh,
              icon: loading
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
    );
  }
}

class _HistoryFilter extends StatelessWidget {
  final bool onlyMine;
  final ValueChanged<bool> onChanged;

  const _HistoryFilter({
    required this.onlyMine,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Expanded(
              child: _FilterButton(
                selected: !onlyMine,
                label: 'Todas',
                onTap: () => onChanged(false),
              ),
            ),
            Expanded(
              child: _FilterButton(
                selected: onlyMine,
                label: 'Minhas',
                onTap: () => onChanged(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;

  const _FilterButton({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.surface : AppColors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryMatchCard extends StatelessWidget {
  final HistoryMatch match;
  final VoidCallback onTap;

  const _HistoryMatchCard({
    required this.match,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teamA = _colorFromHex(match.teamAColorHex);
    final teamB = _colorFromHex(match.teamBColorHex);
    final date = match.playedAt;
    final month =
        date == null ? '---' : DateFormat('MMM', 'pt_BR').format(date);
    final day = date == null ? '--' : DateFormat('dd').format(date);
    final time = date == null ? '--:--' : DateFormat('HH:mm').format(date);
    final draw = match.hasScore && match.teamAGoals == match.teamBGoals;
    final winnerColor = match.hasScore
        ? match.teamAGoals! > match.teamBGoals!
            ? teamA
            : match.teamBGoals! > match.teamAGoals!
                ? teamB
                : null
        : null;

    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: winnerColor,
                  gradient: draw
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [.46, .54],
                          colors: [
                            teamA ?? theme.colorScheme.outline,
                            teamB ?? theme.colorScheme.outline,
                          ],
                        )
                      : null,
                ),
              ),
              // `.proto-history-date` tem borda à direita separando a data do
              // conteúdo, e o dia em 22px/900 — é a âncora visual da linha.
              SizedBox(
                width: 64,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    border: Border(
                      right:
                          BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          month.toUpperCase(),
                          style: theme.textTheme.labelSmall,
                        ),
                        Text(
                          day,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 22,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(time, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _TeamDot(color: teamA),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Text(
                              'VS',
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                          _TeamDot(color: teamB),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              match.placeName ?? 'Local não informado',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // O protótipo põe o placar numa caixa escura destacada
              // (`.proto-history-score`: 60×46, raio 13, fundo #0b1326). Aqui
              // era texto solto, e o placar — que é a informação principal da
              // linha — se perdia no meio do card.
              if (match.hasScore)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 60),
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.darkApp,
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadow20,
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${match.teamAGoals}',
                            style: const TextStyle(
                              color: AppColors.onDark,
                              fontSize: 17,
                              height: 1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 5),
                            child: Text(
                              '×',
                              style: TextStyle(
                                color: AppColors.darkTextMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${match.teamBGoals}',
                            style: const TextStyle(
                              color: AppColors.onDark,
                              fontSize: 17,
                              height: 1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Icon(Icons.chevron_right_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamDot extends StatelessWidget {
  final Color? color;

  const _TeamDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.outline,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}

class _HistorySkeletons extends StatelessWidget {
  const _HistorySkeletons();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (index) => Container(
          height: 88,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _NoGroupState extends StatelessWidget {
  const _NoGroupState();

  @override
  Widget build(BuildContext context) {
    return const _CenteredHistoryState(
      icon: Icons.groups_outlined,
      title: 'Nenhuma patota ativa',
      subtitle: 'Selecione uma patota para ver o histórico.',
    );
  }
}

class _HistoryEmpty extends StatelessWidget {
  final bool onlyMine;

  const _HistoryEmpty({required this.onlyMine});

  @override
  Widget build(BuildContext context) {
    return _CenteredHistoryState(
      icon: Icons.calendar_month_outlined,
      title: 'Nenhuma partida neste filtro',
      subtitle: onlyMine
          ? 'Você ainda não participou de partidas finalizadas.'
          : 'As partidas finalizadas aparecerão aqui.',
    );
  }
}

class _HistoryError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _HistoryError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _CenteredHistoryState(
      icon: Icons.error_outline_rounded,
      title: 'Não foi possível carregar',
      subtitle: '$error',
      action: OutlinedButton(
        onPressed: onRetry,
        child: const Text('Tentar novamente'),
      ),
    );
  }
}

class _CenteredHistoryState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _CenteredHistoryState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrototypeIconBox(size: 52, icon: Icon(icon, size: 25)),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (action != null) ...[
              const SizedBox(height: 14),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

Color? _colorFromHex(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    var hex = raw.replaceAll('#', '').trim();
    if (hex.length == 3) {
      hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
    }
    return Color(int.parse('FF$hex', radix: 16));
  } catch (_) {
    return null;
  }
}

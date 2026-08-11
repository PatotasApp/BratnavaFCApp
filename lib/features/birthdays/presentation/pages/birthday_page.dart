import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../../../shared/presentation/widgets/app_page_header.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../domain/entities/birthday_status.dart';
import '../providers/birthday_provider.dart';

// ── Month names (mirrors site's MONTH_NAMES) ──────────────────────────────────

const _kMonthNames = [
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

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Days until next birthday — mirrors site's daysUntilBirthday()
int _daysUntil(int month, int day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final thisYear = DateTime(today.year, month, day);
  final diff = thisYear.difference(today).inDays;
  return diff >= 0 ? diff : diff + 365;
}

// ── Page ──────────────────────────────────────────────────────────────────────

class BirthdayPage extends ConsumerWidget {
  const BirthdayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupId =
        ref.watch(accountStoreProvider).activeAccount?.activeGroupId;

    if (groupId == null || groupId.isEmpty) {
      return Scaffold(
        body: const Column(
          children: [
            AppPageHeader(
              title: 'Aniversários',
              subtitle: 'Datas especiais dos jogadores da patota',
              icon: Icons.cake_outlined,
            ),
            Expanded(child: _NoGroupState()),
          ],
        ),
      );
    }

    final async = ref.watch(birthdayStatusProvider(groupId));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(birthdayStatusProvider(groupId)),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _Header(async: async),
            ),
            async.when(
              loading: () => const SliverToBoxAdapter(child: _SkeletonList()),
              error: (e, _) => SliverToBoxAdapter(
                  child: _ErrorState(message: extractDioError(e))),
              data: (players) => _BirthdayContent(
                players: players,
                groupId: groupId,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final AsyncValue<List<BirthdayStatus>> async;

  const _Header({required this.async});

  @override
  Widget build(BuildContext context) {
    final loading = async.isLoading;
    final players = async.valueOrNull ?? [];
    final withBd = players.where((p) => p.hasBirthday).length;
    final total = players.length;

    return AppPageHeader(
      title: 'Aniversários',
      subtitle: loading
          ? 'Carregando aniversários...'
          : '$withBd de $total jogadores com data cadastrada',
      icon: Icons.cake_outlined,
    );
  }
}

// ── Content sliver ────────────────────────────────────────────────────────────

class _BirthdayContent extends StatelessWidget {
  final List<BirthdayStatus> players;
  final String groupId;
  const _BirthdayContent({required this.players, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final withBd = players.where((p) => p.hasBirthday).toList();
    final withoutBd = players.where((p) => !p.hasBirthday).toList();

    if (players.isEmpty) {
      return const SliverToBoxAdapter(child: _EmptyState());
    }

    // Preserve backend month ordering (sorted by proximity)
    final monthOrder = <int>[];
    final seen = <int>{};
    for (final p in withBd) {
      if (p.birthMonth != null && seen.add(p.birthMonth!)) {
        monthOrder.add(p.birthMonth!);
      }
    }
    final byMonth = <int, List<BirthdayStatus>>{};
    for (final p in withBd) {
      byMonth.putIfAbsent(p.birthMonth!, () => []).add(p);
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        // Month groups
        for (final month in monthOrder)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _MonthCard(
              month: month,
              players: byMonth[month]!,
              groupId: groupId,
            ),
          ),

        // "Sem data cadastrada" section
        if (withoutBd.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _NoDateCard(players: withoutBd, groupId: groupId),
          ),
      ]),
    );
  }
}

// ── Month card ────────────────────────────────────────────────────────────────

class _MonthCard extends StatelessWidget {
  final int month;
  final List<BirthdayStatus> players;
  final String groupId;
  const _MonthCard({
    required this.month,
    required this.players,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = players.length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.onDark,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: isDark ? AppColors.slate900 : AppColors.slate50,
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.cake_outlined,
                      size: 13, color: AppColors.warning),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _kMonthNames[month - 1],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.slate100 : AppColors.slate800,
                    ),
                  ),
                ),
                Text(
                  '$count jogador${count != 1 ? 'es' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.slate500 : AppColors.slate400,
                  ),
                ),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: isDark ? AppColors.slate700 : AppColors.slate100),
          // Player rows
          ...players.map((p) => _PlayerRow(player: p, groupId: groupId)),
        ],
      ),
    );
  }
}

// ── Player row ────────────────────────────────────────────────────────────────

class _PlayerRow extends StatelessWidget {
  final BirthdayStatus player;
  final String groupId;
  const _PlayerRow({required this.player, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = _daysUntil(player.birthMonth!, player.birthDay!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.slate700 : AppColors.slate100,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Day chip — amber circle with day number
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color:
                  isDark ? AppColors.warning.withAlpha(50) : AppColors.amber50,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? AppColors.warning.withAlpha(100)
                    : AppColors.amber200,
              ),
            ),
            child: Center(
              child: Text(
                '${player.birthDay}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.warning : AppColors.warningLight,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: ConfiguredPlayerName(
              groupId: groupId,
              name: player.name,
              isGoalkeeper: player.isGoalkeeper,
              iconSize: 13,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.slate200 : AppColors.slate800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Countdown badge
          _CountdownBadge(days: days),
        ],
      ),
    );
  }
}

// ── Countdown badge ───────────────────────────────────────────────────────────
// Mirrors site's <CountdownBadge /> exactly

class _CountdownBadge extends StatelessWidget {
  final int days;
  const _CountdownBadge({required this.days});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (days == 0) {
      return _pill(
        label: '🎂 Hoje!',
        bg: isDark ? AppColors.warning.withAlpha(100) : AppColors.amber50,
        fg: isDark ? AppColors.warning : AppColors.warningLight,
        border: isDark ? AppColors.warning.withAlpha(120) : AppColors.amber200,
        bold: true,
      );
    }
    if (days <= 7) {
      return _pill(
        label: 'em ${days}d',
        bg: isDark ? AppColors.warning.withAlpha(100) : AppColors.amber50,
        fg: isDark ? AppColors.warning : AppColors.warningLight,
        border: isDark ? AppColors.warning.withAlpha(120) : AppColors.amber200,
        bold: false,
      );
    }
    if (days <= 30) {
      return _pill(
        label: 'em ${days}d',
        bg: isDark ? AppColors.blue500.withAlpha(100) : AppColors.blue50,
        fg: isDark ? AppColors.blue200 : AppColors.infoLight,
        border: isDark ? AppColors.blue500.withAlpha(120) : AppColors.blue200,
        bold: false,
      );
    }
    // Far away — plain text
    return Text(
      '${days}d',
      style: TextStyle(
        fontSize: 12,
        color: isDark ? AppColors.slate500 : AppColors.slate400,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _pill({
    required String label,
    required Color bg,
    required Color fg,
    required Color border,
    required bool bold,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: fg,
          ),
        ),
      );
}

// ── "Sem data cadastrada" card ────────────────────────────────────────────────

class _NoDateCard extends StatelessWidget {
  final List<BirthdayStatus> players;
  final String groupId;
  const _NoDateCard({required this.players, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = players.length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.onDark,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: isDark ? AppColors.slate900 : AppColors.slate50,
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.slate400.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.person_off_outlined,
                      size: 13,
                      color: isDark ? AppColors.slate500 : AppColors.slate400),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sem data cadastrada',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.slate100 : AppColors.slate800,
                    ),
                  ),
                ),
                Text(
                  '$count jogador${count != 1 ? 'es' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.slate500 : AppColors.slate400,
                  ),
                ),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: isDark ? AppColors.slate700 : AppColors.slate100),
          // Player rows — dot + name (muted)
          ...players.map((p) {
            final isDarkCtx = isDark;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDarkCtx ? AppColors.slate700 : AppColors.slate100,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          isDarkCtx ? AppColors.slate600 : AppColors.slate300,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ConfiguredPlayerName(
                      groupId: groupId,
                      name: p.name,
                      isGoalkeeper: p.isGoalkeeper,
                      iconSize: 13,
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            isDarkCtx ? AppColors.slate400 : AppColors.slate500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Skeleton loading ──────────────────────────────────────────────────────────

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          for (var i = 0; i < 3; i++) ...[
            _SkeletonCard(isDark: isDark),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  final bool isDark;
  const _SkeletonCard({required this.isDark});
  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 0.9)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.isDark ? AppColors.slate800 : AppColors.slate100;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ── Empty / Error / No-group states ──────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate800 : AppColors.onDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? AppColors.slate700 : AppColors.slate200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cake_outlined,
                size: 40,
                color: (isDark ? AppColors.slate500 : AppColors.slate300)),
            const SizedBox(height: 12),
            Text(
              'Nenhum jogador encontrado.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.slate400 : AppColors.slate500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 40, color: AppColors.rose500),
            const SizedBox(height: 10),
            const Text('Erro ao carregar aniversários',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.slate400)),
            const SizedBox(height: 6),
            Text(message,
                style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _NoGroupState extends StatelessWidget {
  const _NoGroupState();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cake_outlined, size: 48, color: AppColors.slate500),
            SizedBox(height: 12),
            Text('Crie ou entre em um grupo',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.slate400, fontSize: 13)),
          ],
        ),
      );
}

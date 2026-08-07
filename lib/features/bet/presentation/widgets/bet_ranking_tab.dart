import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../domain/entities/bet_models.dart';
import '../providers/bet_provider.dart';
import '../../../../core/errors/app_exception.dart';

class BetRankingTab extends ConsumerStatefulWidget {
  final String groupId;
  const BetRankingTab({super.key, required this.groupId});

  @override
  ConsumerState<BetRankingTab> createState() => _BetRankingTabState();
}

class _BetRankingTabState extends ConsumerState<BetRankingTab>
    with AutomaticKeepAliveClientMixin {
  List<BetLeaderboardEntry>? _entries;
  int? _myBalance;
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ds = ref.read(betDsProvider);
      final results = await Future.wait([
        ds.fetchLeaderboard(widget.groupId),
        ds.fetchBalance(widget.groupId),
      ]);
      if (!mounted) return;
      setState(() {
        _entries = results[0] as List<BetLeaderboardEntry>;
        _myBalance = results[1] as int;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = extractDioError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final account = ref.watch(accountStoreProvider).activeAccount;
    final myUserId = account?.userId ?? '';

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }
    if (_entries == null || _entries!.isEmpty) {
      return _EmptyState(isDark: isDark);
    }

    // Find my entry
    final myEntry = _entries!.where((e) => e.userId == myUserId).firstOrNull;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          // ── My summary card ────────────────────────────────────────────
          if (myEntry != null || _myBalance != null)
            _MySummaryCard(
              isDark: isDark,
              balance: _myBalance ?? myEntry?.balance ?? 0,
              rank: myEntry?.rank,
              totalBets: myEntry?.totalBets,
            ),
          if (myEntry != null || _myBalance != null) const SizedBox(height: 14),

          // ── Leaderboard ────────────────────────────────────────────────
          ...List.generate(_entries!.length, (i) {
            final e = _entries![i];
            final isMe = e.userId == myUserId;
            return _LeaderboardRow(
              entry: e,
              isMe: isMe,
              isDark: isDark,
            );
          }),
        ],
      ),
    );
  }
}

// ── My summary card ───────────────────────────────────────────────────────────

class _MySummaryCard extends StatelessWidget {
  final bool isDark;
  final int balance;
  final int? rank;
  final int? totalBets;
  const _MySummaryCard({
    required this.isDark,
    required this.balance,
    this.rank,
    this.totalBets,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.slate800 : AppColors.onDark;
    final border = isDark ? AppColors.slate700 : AppColors.slate200;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(children: [
        // Balance
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Seu saldo',
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.slate400 : AppColors.slate500)),
              const SizedBox(height: 2),
              Row(children: [
                Text(
                  '$balance',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: fichasColor(balance)),
                ),
                const SizedBox(width: 4),
                Text('BC',
                    style: TextStyle(
                        fontSize: 13,
                        color:
                            isDark ? AppColors.slate400 : AppColors.slate500)),
              ]),
            ],
          ),
        ),

        // Divider
        Container(width: 1, height: 44, color: border),
        const SizedBox(width: 14),

        // Rank
        if (rank != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Posição',
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.slate400 : AppColors.slate500)),
              const SizedBox(height: 2),
              Text(
                '#$rank',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.onDark : AppColors.slate800),
              ),
            ],
          ),

        if (rank != null && totalBets != null) const SizedBox(width: 14),

        // Total bets
        if (totalBets != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Apostas',
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.slate400 : AppColors.slate500)),
              const SizedBox(height: 2),
              Text(
                '$totalBets',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.onDark : AppColors.slate800),
              ),
            ],
          ),
      ]),
    );
  }
}

// ── Leaderboard row ───────────────────────────────────────────────────────────

class _LeaderboardRow extends StatelessWidget {
  final BetLeaderboardEntry entry;
  final bool isMe;
  final bool isDark;
  const _LeaderboardRow({
    required this.entry,
    required this.isMe,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.slate800 : AppColors.onDark;
    final border = isMe
        ? AppColors.info
        : (isDark ? AppColors.slate700 : AppColors.slate200);
    final rankColor = entry.rank <= 3
        ? AppColors.warning
        : (isDark ? AppColors.slate400 : AppColors.slate500);

    String? medal;
    if (entry.rank == 1) medal = '🥇';
    if (entry.rank == 2) medal = '🥈';
    if (entry.rank == 3) medal = '🥉';

    final accuracy = entry.totalBets > 0
        ? (entry.totalCorrect / entry.totalBets * 100).round()
        : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: isMe ? 2 : 1),
      ),
      child: Row(children: [
        // Rank / medal
        SizedBox(
          width: 32,
          child: medal != null
              ? Text(medal,
                  style: const TextStyle(fontSize: 20),
                  textAlign: TextAlign.center)
              : Text('#${entry.rank}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: rankColor),
                  textAlign: TextAlign.center),
        ),
        const SizedBox(width: 8),

        // Name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(entry.userName,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.onDark : AppColors.slate800)),
                if (isMe) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Você',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.info)),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text(
                '${entry.totalBets} aposta${entry.totalBets != 1 ? "s" : ""}  ·  $accuracy% acertos',
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.slate500 : AppColors.slate400),
              ),
            ],
          ),
        ),

        // Balance
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${entry.balance >= 0 ? "" : ""}${entry.balance}',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: fichasColor(entry.balance)),
            ),
            Text('BC',
                style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.slate500 : AppColors.slate400)),
          ],
        ),
      ]),
    );
  }
}

// ── Empty / error states ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.leaderboard_outlined,
              size: 44,
              color: isDark ? AppColors.slate700 : AppColors.slate200),
          const SizedBox(height: 12),
          Text('Nenhuma entrada no ranking.',
              style: TextStyle(
                  color: isDark ? AppColors.slate500 : AppColors.slate400)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 44, color: AppColors.prototypeDanger),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.prototypeDanger)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

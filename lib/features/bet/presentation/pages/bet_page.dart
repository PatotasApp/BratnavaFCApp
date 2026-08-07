import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../widgets/current_bet_tab.dart';
import '../widgets/bet_history_tab.dart';
import '../widgets/bet_ranking_tab.dart';

class BetPage extends ConsumerStatefulWidget {
  const BetPage({super.key});

  @override
  ConsumerState<BetPage> createState() => _BetPageState();
}

class _BetPageState extends ConsumerState<BetPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final account = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    // O jogador manda no grupo: `activeGroupId` da conta pode apontar
    // para uma patota sem jogador nosso, e aí toda rota por grupo
    // responde 403. Ver dashboard_page para o diagnóstico completo.
    final groupId = activePlayer?.groupId ?? account?.activeGroupId ?? '';

    if (groupId.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sports_soccer_outlined,
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
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          // ── Header ─────────────────────────────────────────────────────────
          const _BetHeader(),

          // ── TabBar ─────────────────────────────────────────────────────────
          Container(
            color: isDark ? AppColors.slate900 : AppColors.onDark,
            child: TabBar(
              controller: _tabCtrl,
              tabs: const [
                Tab(text: 'Aposta Atual'),
                Tab(text: 'Histórico'),
                Tab(text: 'Ranking'),
              ],
              labelColor: isDark ? AppColors.onDark : AppColors.slate900,
              unselectedLabelColor:
                  isDark ? AppColors.slate500 : AppColors.slate400,
              indicatorColor: isDark ? AppColors.onDark : AppColors.slate900,
              labelStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),

          // ── TabBarView ─────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                CurrentBetTab(groupId: groupId),
                BetHistoryTab(groupId: groupId),
                BetRankingTab(groupId: groupId),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _BetHeader extends StatelessWidget {
  const _BetHeader();

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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          IconButton(
            tooltip: 'Voltar',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/app');
              }
            },
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.onDark.withAlpha(20),
              foregroundColor: AppColors.onDark,
              side: BorderSide(color: AppColors.onDark.withAlpha(40)),
            ),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.onDark),
          ),
          const SizedBox(width: 4),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.onDark.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.onDark.withValues(alpha: .2)),
            ),
            child: const Icon(Icons.monetization_on_outlined,
                size: 22, color: AppColors.onDark),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Bet',
                style: TextStyle(
                  color: AppColors.onDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                )),
          ),
        ]),
      ),
    );
  }
}

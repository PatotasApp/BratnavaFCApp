import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../group_settings/presentation/providers/group_settings_provider.dart';
import '../../domain/entities/recent_match.dart';

class RecentMatchCard extends ConsumerWidget {
  final RecentMatch match;
  final String groupId;

  const RecentMatchCard({
    super.key,
    required this.match,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = match.playedAt;

    final month =
        DateFormat('MMM', 'pt_BR').format(d).toUpperCase().replaceAll('.', '');
    final day = DateFormat('dd').format(d);
    final time = DateFormat('HH:mm').format(d);

    final myHex = match.myTeamColor?.hexValue;
    final myName = match.myTeamColor?.name;
    const hasScore = true; // sempre mostra

    final (outcomeLabel, outcomeFg, outcomeBg, outcomeBorder) =
        switch (match.outcome) {
      MatchOutcome.win => (
          'Vitória',
          AppColors.emerald700,
          AppColors.emerald50,
          AppColors.emerald200
        ),
      MatchOutcome.draw => (
          'Empate',
          AppColors.amber500,
          AppColors.amber50,
          AppColors.amber200
        ),
      MatchOutcome.loss => (
          'Derrota',
          AppColors.rose600,
          AppColors.rose50,
          AppColors.rose200
        ),
    };

    final borderColor = isDark ? AppColors.slate700 : AppColors.slate200;

    // Ícones da patota (com fallback para defaults enquanto carrega)
    final settings = ref.watch(groupSettingsProvider(groupId)).valueOrNull;
    final icons = GroupIcons.from(settings);

    final account = ref.watch(accountStoreProvider).activeAccount;
    final isGroupAdm = account != null && account.isGroupAdmin(groupId);
    final canSeeStats = isGroupAdm || (settings?.showPlayerStats ?? false);

    return GestureDetector(
      onTap: () => context.push('/app/history/$groupId/${match.matchId}'),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : AppColors.onDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Faixa lateral (slate neutro — igual ao site) ─────────────
              Container(
                width: 4,
                color: isDark ? AppColors.slate700 : AppColors.slate200,
              ),

              // ── Caixa de data ─────────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.slate800.withValues(alpha: .5)
                      : AppColors.slate50,
                  border: Border(
                    right: BorderSide(
                      color: isDark ? AppColors.slate800 : AppColors.slate100,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      month,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: isDark ? AppColors.slate500 : AppColors.slate400,
                      ),
                    ),
                    Text(
                      day,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                        color: isDark ? AppColors.slate100 : AppColors.slate800,
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.slate500 : AppColors.slate400,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Info + placar ─────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Badges: cor do time + resultado + gols + assistências
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Cor do time do jogador
                            if (myHex != null || myName != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (myHex != null) _ColorDot(hex: myHex),
                                  if (myHex != null) const SizedBox(width: 4),
                                  if (myName != null)
                                    Text(
                                      myName,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? AppColors.slate400
                                            : AppColors.slate500,
                                      ),
                                    ),
                                ],
                              )
                            // Sem time definido: mostra os dois times vs
                            else if (match.myTeamColor != null ||
                                match.opponentColor != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (match.myTeamColor != null)
                                    _ColorDot(hex: match.myTeamColor!.hexValue),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 3),
                                    child: Text(
                                      'vs',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? AppColors.slate600
                                            : AppColors.slate300,
                                      ),
                                    ),
                                  ),
                                  if (match.opponentColor != null)
                                    _ColorDot(
                                        hex: match.opponentColor!.hexValue),
                                ],
                              ),

                            // Badge resultado
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: outcomeBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: outcomeBorder),
                              ),
                              child: Text(
                                outcomeLabel,
                                style: TextStyle(
                                  color: outcomeFg,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            // Badge MVP (usa ícone configurado pelo grupo)
                            if (match.isMvp)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.amber50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.amber200),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    renderGroupIcon(icons.mvp,
                                        size: 10, color: AppColors.amber500),
                                    const SizedBox(width: 3),
                                    const Text('MVP',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.amber500,
                                        )),
                                  ],
                                ),
                              ),

                            // Gols
                            if (canSeeStats && match.goals > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  renderGroupIcon(
                                    icons.goal,
                                    size: 10,
                                    color: isDark
                                        ? AppColors.slate400
                                        : AppColors.slate500,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${match.goals}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? AppColors.slate400
                                          : AppColors.slate500,
                                    ),
                                  ),
                                ],
                              ),

                            // Assistências
                            if (canSeeStats && match.assists > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  renderGroupIcon(
                                    icons.assist,
                                    size: 10,
                                    color: isDark
                                        ? AppColors.slate400
                                        : AppColors.slate500,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${match.assists}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? AppColors.slate400
                                          : AppColors.slate500,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // ── Placar ────────────────────────────────────────────
                      if (hasScore)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.slate700
                                : AppColors.slate900,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${match.myTeamGoals}',
                                style: const TextStyle(
                                  color: AppColors.onDark,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 3),
                                child: Text(
                                  '×',
                                  style: TextStyle(
                                    color: AppColors.slate500,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              Text(
                                '${match.opponentGoals}',
                                style: const TextStyle(
                                  color: AppColors.onDark,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
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
}

// ── ColorDot ─────────────────────────────────────────────────────────────────

class _ColorDot extends StatelessWidget {
  final String hex;
  const _ColorDot({required this.hex});

  @override
  Widget build(BuildContext context) {
    Color? color;
    try {
      color = Color(int.parse('0xFF${hex.replaceAll('#', '')}'));
    } catch (_) {
      color = null;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (color == null) {
      return Container(
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      );
    }
    final isWhite = hex.toLowerCase().replaceAll('#', '') == 'ffffff';
    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: isWhite
              ? AppColors.slate300
              : AppColors.onDark.withValues(alpha: .3),
          width: 1,
        ),
      ),
    );
  }
}

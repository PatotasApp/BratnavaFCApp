import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../group_settings/presentation/providers/group_settings_provider.dart';
import '../providers/match_provider.dart';

class Step7FinalPage extends ConsumerStatefulWidget {
  const Step7FinalPage({super.key});

  @override
  ConsumerState<Step7FinalPage> createState() => _Step7FinalPageState();
}

class _Step7FinalPageState extends ConsumerState<Step7FinalPage> {
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(matchNotifierProvider);
    final groupId =
        ref.watch(accountStoreProvider).activeAccount?.activeGroupId ?? '';
    final icons =
        GroupIcons.from(ref.watch(groupSettingsProvider(groupId)).valueOrNull);
    final fmt = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
    final dateStr = s.playedAt != null ? fmt.format(s.playedAt!) : '—';
    final hasMvp = s.computedMvps.isNotEmpty;
    final hasScore = s.teamAGoals != null && s.teamBGoals != null;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Badge Finalizado ──────────────────────────────────
                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppColors.warning, AppColors.amber500]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.warning.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3)),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag_rounded,
                            color: AppColors.onDark, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Finalizada',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.onDark,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Info da partida ───────────────────────────────────
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _InfoRow(icon: Icons.calendar_today, text: dateStr),
                        const SizedBox(height: 6),
                        _InfoRow(
                            icon: Icons.location_on, text: s.placeName ?? '—'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Placar final ──────────────────────────────────────
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text(
                          'PLACAR FINAL',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 1.5,
                            color: AppColors.slate500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!hasScore)
                          const Text(
                            'Placar não disponível',
                            style: TextStyle(
                                color: AppColors.slate400, fontSize: 15),
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _TeamScoreBlock(
                                name: s.teamAColor?.name ?? 'Time A',
                                goals: s.teamAGoals!,
                                color: s.teamAColor?.color,
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20),
                                child: Text('×',
                                    style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w300,
                                        color: AppColors.slate400)),
                              ),
                              _TeamScoreBlock(
                                name: s.teamBColor?.name ?? 'Time B',
                                goals: s.teamBGoals!,
                                color: s.teamBColor?.color,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── MVP ───────────────────────────────────────────────
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            renderGroupIcon(
                              icons.mvp,
                              color: AppColors.warning,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            const Text('MVP',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 18)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (hasMvp)
                          ...s.computedMvps.map((m) {
                            final player = s.participants
                                .where((p) => p.playerId == m.playerId)
                                .firstOrNull;
                            return PlayerNameWithIcon(
                              name: m.playerName,
                              isGoalkeeper: player?.isGoalkeeper ?? false,
                              icons: icons,
                              iconSize: 18,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          })
                        else
                          const Text(
                            '—',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.slate400,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Resultados por time ───────────────────────────────
                if (hasScore && s.teamAColor != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Resultado',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(height: 12),
                          _ResultRow(
                            teamName: s.teamAColor?.name ?? 'Time A',
                            teamColor: s.teamAColor?.color,
                            goals: s.teamAGoals!,
                            isWinner: s.teamAGoals! > s.teamBGoals!,
                            isDraw: s.teamAGoals == s.teamBGoals,
                          ),
                          const SizedBox(height: 6),
                          _ResultRow(
                            teamName: s.teamBColor?.name ?? 'Time B',
                            teamColor: s.teamBColor?.color,
                            goals: s.teamBGoals!,
                            isWinner: s.teamBGoals! > s.teamAGoals!,
                            isDraw: s.teamAGoals == s.teamBGoals,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: AppColors.slate400),
        const SizedBox(width: 8),
        Flexible(child: Text(text, style: const TextStyle(fontSize: 14))),
      ]);
}

class _TeamScoreBlock extends StatelessWidget {
  final String name;
  final int goals;
  final Color? color;
  const _TeamScoreBlock({required this.name, required this.goals, this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: color ?? AppColors.slate300),
        ),
        const SizedBox(height: 4),
        Text('$goals',
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800)),
        Text(name,
            style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
      ]);
}

class _ResultRow extends StatelessWidget {
  final String teamName;
  final Color? teamColor;
  final int goals;
  final bool isWinner;
  final bool isDraw;
  const _ResultRow(
      {required this.teamName,
      this.teamColor,
      required this.goals,
      required this.isWinner,
      required this.isDraw});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: teamColor ?? AppColors.slate300)),
        const SizedBox(width: 8),
        Expanded(child: Text(teamName, style: const TextStyle(fontSize: 14))),
        Text('$goals',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isDraw
                ? AppColors.amber200
                : isWinner
                    ? AppColors.emerald200
                    : AppColors.rose200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            isDraw
                ? 'Empate'
                : isWinner
                    ? 'Vitória'
                    : 'Derrota',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDraw
                  ? AppColors.warningLight
                  : isWinner
                      ? AppColors.emerald700
                      : AppColors.rose600,
            ),
          ),
        ),
      ]);
}

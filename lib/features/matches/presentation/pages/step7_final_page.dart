import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/match_provider.dart';

class Step7FinalPage extends ConsumerStatefulWidget {
  const Step7FinalPage({super.key});

  @override
  ConsumerState<Step7FinalPage> createState() => _Step7FinalPageState();
}

class _Step7FinalPageState extends ConsumerState<Step7FinalPage> {
  bool _reapplyingMvp = false;

  Future<void> _reapplyMvp() async {
    final s = ref.read(matchNotifierProvider);
    final matchId = s.matchId;
    if (matchId == null || matchId.isEmpty) return;
    final ds = ref.read(matchDsProvider);
    final notifier = ref.read(matchNotifierProvider.notifier);
    setState(() => _reapplyingMvp = true);
    try {
      await ds.reapplyMvp(notifier.groupId, matchId);
      await notifier.refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('MVP recalculado com sucesso')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  extractDioError(e, 'Não foi possível recalcular o MVP'))),
        );
      }
    } finally {
      if (mounted) setState(() => _reapplyingMvp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(matchNotifierProvider);
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
                          colors: [AppColors.amber400, AppColors.amber500]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.amber400.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3)),
                      ],
                    ),
                    child: const Text(
                      '🏁 Finalizada',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontSize: 16),
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
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.emoji_events,
                                color: AppColors.amber400, size: 28),
                            SizedBox(width: 8),
                            Text('MVP',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 18)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          hasMvp
                              ? s.computedMvps
                                  .map((m) => m.playerName)
                                  .join(', ')
                              : '—',
                          style: TextStyle(
                            fontSize: hasMvp ? 20 : 16,
                            fontWeight:
                                hasMvp ? FontWeight.w700 : FontWeight.w400,
                            color: hasMvp ? null : AppColors.slate400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Recalcular MVP ────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _reapplyingMvp ? null : _reapplyMvp,
                    icon: _reapplyingMvp
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Recalcular MVP'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.amber500,
                      side: const BorderSide(color: AppColors.amber400),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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
                  ? AppColors.orange700
                  : isWinner
                      ? AppColors.emerald700
                      : AppColors.rose600,
            ),
          ),
        ),
      ]);
}

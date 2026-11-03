import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/team_builder_models.dart';
import '../../domain/team_builder_format.dart';
import 'team_builder_pitch.dart';

/// Largura lógica da imagem; com pixelRatio 3 sai em 1080 × 1920 (9:16).
const teamBuilderShareCardWidth = 360.0;
const teamBuilderShareLogo = 'assets/images/logo_icon_source_transparent.png';

/// Imagem para o story: o time no campo, os números de juntos e a marca PatotasApp.
class TeamBuilderShareCard extends StatelessWidget {
  const TeamBuilderShareCard({
    super.key,
    required this.stats,
    required this.players,
    required this.groupName,
    required this.period,
  });

  final TeamBuilderStats stats;
  final List<TeamBuilderPlayer> players;
  final String groupName;
  final String period;

  @override
  Widget build(BuildContext context) {
    const w = teamBuilderShareCardWidth;
    final n = stats.totalMatches == 0 ? 1 : stats.totalMatches;
    const white = AppColors.onDark;

    Widget box(String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
                color: AppColors.onDark10,
                borderRadius: BorderRadius.circular(11)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        color: white)),
                const SizedBox(height: 4),
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.onDark70)),
              ],
            ),
          ),
        );

    return SizedBox(
      width: w,
      height: w * 16 / 9,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-.2, -1),
            end: Alignment(.2, 1),
            colors: [
              AppColors.darkApp,
              AppColors.shareCardMid,
              AppColors.accentBackground
            ],
            stops: [0, .6, 1],
          ),
        ),
        child: DefaultTextStyle(
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: white),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(25, 29, 25, 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MONTE SEU TIME · ${groupName.toUpperCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onDark70),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        joinNames(players.map((p) => p.shortName).toList()),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.08,
                            color: white),
                      ),
                      const SizedBox(height: 12),
                      // Encolhe se o nome do time ocupar mais linhas: a imagem nunca transborda.
                      Flexible(
                        child: TeamBuilderPitch(
                          players: players,
                          aspectRatio: 4 / 3.3,
                          radius: 14,
                          sub: (p) {
                            final b = stats.breakdownOf(p.id);
                            return b == null ? '' : '${b.goals}G ${b.assists}A';
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        box('${stats.pointsPct}%', 'aproveitamento'),
                        const SizedBox(width: 11),
                        box('${stats.totalMatches}', 'jogos juntos'),
                        const SizedBox(width: 11),
                        box(oneDecimal(stats.goalsPerMatch), 'gols por jogo'),
                      ]),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 8,
                          child: Row(children: [
                            if (stats.wins > 0)
                              Expanded(
                                  flex: stats.wins * 1000 ~/ n,
                                  child: const ColoredBox(
                                      color: AppColors.accent)),
                            if (stats.draws > 0)
                              Expanded(
                                  flex: stats.draws * 1000 ~/ n,
                                  child: const ColoredBox(
                                      color: AppColors.warning)),
                            if (stats.losses > 0)
                              Expanded(
                                  flex: stats.losses * 1000 ~/ n,
                                  child: const ColoredBox(
                                      color: AppColors.prototypeDanger)),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                            color: AppColors.shadow34,
                            borderRadius: BorderRadius.circular(11)),
                        child: Text(
                          '${stats.wins}V ${stats.draws}E ${stats.losses}D · juntos ${stats.pointsPct}% · média deles ${stats.averageIndividualPointsPct}%',
                          style: const TextStyle(
                              fontSize: 13, height: 1.4, color: white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                        color: white, borderRadius: BorderRadius.circular(9)),
                    child:
                        Image.asset(teamBuilderShareLogo, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text.rich(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            TextSpan(children: [
                              TextSpan(text: 'Patotas'),
                              TextSpan(
                                  text: 'App',
                                  style: TextStyle(color: AppColors.accent)),
                            ]),
                            style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                                color: white)),
                        Text(period,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 10.5, color: AppColors.onDark70)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('patotasapp.com.br',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onDark70)),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

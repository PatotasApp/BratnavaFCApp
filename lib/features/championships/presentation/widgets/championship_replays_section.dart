import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/presentation/widgets/prototype_ui.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../replays/domain/entities/replay_clip.dart';
import '../../../replays/presentation/pages/replay_video_player_page.dart';
import '../../domain/entities/championship_models.dart';
import '../providers/championship_provider.dart';

/// Link público do modo cinema do campeonato (site).
String championshipCinemaUrl(String championshipId) =>
    '${AppConstants.webUrl}/public/championship/$championshipId/cinema';

/// Vídeos do campeonato separados por jogo; em cada jogo, Gol de cada time e
/// Jogada. O botão do topo compartilha o modo cinema do campeonato.
class ChampionshipReplaysSection extends ConsumerWidget {
  const ChampionshipReplaysSection({
    super.key,
    required this.details,
    required this.groupId,
  });

  final ChampionshipDetails details;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final replays = ref.watch(championshipReplaysProvider(details.id));
    final token = ref.watch(idTokenProvider).valueOrNull;

    return PrototypeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.movie_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Vídeos',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              TextButton.icon(
                onPressed: () => Share.share(
                  'Modo cinema · ${details.name}\n'
                  '${championshipCinemaUrl(details.id)}',
                ),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Modo cinema'),
              ),
            ],
          ),
          replays.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
            error: (_, __) => const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Não foi possível carregar os vídeos.'),
            ),
            data: (data) => data.games.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Os vídeos aparecem aqui, separados por jogo.'),
                  )
                : Column(
                    children: [
                      for (final game in data.games)
                        _GameReplays(
                          game: game,
                          details: details,
                          groupId: groupId,
                          token: token,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _GameReplays extends StatelessWidget {
  const _GameReplays({
    required this.game,
    required this.details,
    required this.groupId,
    required this.token,
  });

  final ChampionshipGameReplays game;
  final ChampionshipDetails details;
  final String groupId;
  final String? token;

  List<ReplayClip> _asReplayClips() => [
        for (final clip in game.clips)
          ReplayClip(
            clipId: clip.id,
            matchId: game.gameId,
            matchDate: details.playedAt.toIso8601String(),
            matchPlace: details.placeName,
            videoUrl: clip.url,
            eventType: clip.eventType,
            teamName: clip.eventType == 'GolTimeA'
                ? game.teamAName
                : clip.eventType == 'GolTimeB'
                    ? game.teamBName
                    : null,
            isLiked: false,
            isFavorited: false,
            likeCount: 0,
            createdAt: clip.recordedAt.toIso8601String(),
          ),
      ];

  void _open(BuildContext context, ChampionshipReplayClip clip) {
    final clips = _asReplayClips();
    final index = game.clips.indexOf(clip);
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ReplayVideoPlayerPage(
        clips: clips,
        initialIndex: index < 0 ? 0 : index,
        groupId: groupId,
        accessToken: token,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final groups = [
      ('Gol ${game.teamAName}', 'GolTimeA'),
      ('Gol ${game.teamBName}', 'GolTimeB'),
      ('Jogada', 'Jogada'),
    ];
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text('Jogo ${game.order} · ${game.teamAName} '
          '${game.teamAGoals ?? 0} × ${game.teamBGoals ?? 0} ${game.teamBName}'),
      subtitle: Text('${game.clips.length} vídeo(s)'),
      children: [
        for (final (label, type) in groups) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
          ),
          if (game.clips.every((c) => c.eventType != type))
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Nenhum vídeo.'),
            ),
          for (final clip in game.clips.where((c) => c.eventType == type))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_circle_outline_rounded),
              title: Text(clip.label),
              subtitle: Text(DateFormat('HH:mm:ss').format(clip.recordedAt)),
              onTap: clip.url.isEmpty ? null : () => _open(context, clip),
            ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

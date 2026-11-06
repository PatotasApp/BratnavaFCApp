import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/presentation/widgets/prototype_ui.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../../../history/presentation/widgets/match_replays_section.dart';
import '../../../replays/domain/entities/replay_clip.dart';
import '../../domain/entities/championship_models.dart';
import '../providers/championship_provider.dart';

/// Link público do modo cinema do campeonato (site).
String championshipCinemaUrl(String championshipId) =>
    '${AppConstants.shareUrl}/public/championship/$championshipId/cinema';

/// Vídeos do campeonato separados por jogo, com a mesma seção de vídeos da
/// partida (miniaturas, filtro e player). Cada jogo é uma partida: os vídeos
/// vêm da mesma rota de replays da partida, com curtidas e favoritos. O botão
/// do topo compartilha o modo cinema do campeonato.
class ChampionshipReplaysSection extends ConsumerStatefulWidget {
  const ChampionshipReplaysSection({
    super.key,
    required this.details,
    required this.groupId,
  });

  final ChampionshipDetails details;
  final String groupId;

  @override
  ConsumerState<ChampionshipReplaysSection> createState() =>
      _ChampionshipReplaysSectionState();
}

class _ChampionshipReplaysSectionState
    extends ConsumerState<ChampionshipReplaysSection> {
  String? _gameId;

  @override
  Widget build(BuildContext context) {
    final replays = ref.watch(championshipReplaysProvider(widget.details.id));
    final details = widget.details;

    return PrototypeCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Row(
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
          ),
          replays.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
            error: (_, __) => const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text('Não foi possível carregar os vídeos.'),
            ),
            data: (data) {
              final games = [...data.games]
                ..sort((a, b) => a.order.compareTo(b.order));
              if (games.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text('Os vídeos aparecem aqui, separados por jogo.'),
                );
              }
              final game =
                  games.where((g) => g.gameId == _gameId).firstOrNull ??
                      games.first;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (games.length > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: PrototypeSegmented(
                        items: [for (final g in games) 'Jogo ${g.order}'],
                        value: 'Jogo ${game.order}',
                        onChanged: (label) => setState(() => _gameId = games
                            .firstWhere((g) => 'Jogo ${g.order}' == label)
                            .gameId),
                        semanticLabel: 'Jogo do campeonato',
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Text(
                      'Jogo ${game.order} · ${game.teamAName} '
                      '${game.teamAGoals ?? 0} × ${game.teamBGoals ?? 0} '
                      '${game.teamBName}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  _GameReplays(
                    key: ValueKey(game.gameId),
                    gameId: game.gameId,
                    groupId: widget.groupId,
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Vídeos de um jogo pela rota de replays da partida, na seção da partida.
class _GameReplays extends ConsumerStatefulWidget {
  const _GameReplays({super.key, required this.gameId, required this.groupId});

  final String gameId;
  final String groupId;

  @override
  ConsumerState<_GameReplays> createState() => _GameReplaysState();
}

class _GameReplaysState extends ConsumerState<_GameReplays> {
  List<ReplayClip>? _clips;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final clips = await ref
          .read(historyDsProvider)
          .fetchMatchReplays(widget.groupId, widget.gameId);
      if (mounted) setState(() => _clips = clips);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Não foi possível carregar os vídeos deste jogo.'),
      );
    }
    final clips = _clips;
    if (clips == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      );
    }
    if (clips.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Nenhum vídeo neste jogo.'),
      );
    }
    return MatchReplaysSection(
      replays: clips,
      groupId: widget.groupId,
      accessToken: ref.watch(idTokenProvider).valueOrNull,
      isDark: Theme.of(context).brightness == Brightness.dark,
    );
  }
}

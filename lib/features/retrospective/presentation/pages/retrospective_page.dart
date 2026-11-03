import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/app_page_header.dart';
import '../../../../shared/presentation/widgets/no_active_group_view.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../domain/entities/player_retrospective.dart';
import '../../domain/retrospective_stories.dart';
import '../providers/retrospective_provider.dart';
import '../widgets/retro_story_card.dart';
import 'retrospective_stories_page.dart';

/// Retrospectiva da temporada (estilo Wrapped). Só o admin da patota vê, e escolhe o jogador.
class RetrospectivePage extends ConsumerStatefulWidget {
  const RetrospectivePage({super.key});

  @override
  ConsumerState<RetrospectivePage> createState() => _RetrospectivePageState();
}

class _RetrospectivePageState extends ConsumerState<RetrospectivePage> {
  String? _playerId;
  int? _year;

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    final groupId = account?.activeGroupId ?? activePlayer?.groupId;
    final isAdmin = groupId != null &&
        groupId.isNotEmpty &&
        (account?.isGroupAdmin(groupId) ?? false);

    return Scaffold(
      body: Column(children: [
        const AppPageHeader(
          title: 'Retrospectiva',
          subtitle: 'A temporada de cada jogador em stories',
          icon: Icons.auto_awesome_outlined,
        ),
        Expanded(
          child: groupId == null || groupId.isEmpty
              ? const NoActiveGroupView(
                  message: 'Selecione uma patota para ver a retrospectiva.')
              : !isAdmin
                  ? const _Message(
                      icon: Icons.lock_outline_rounded,
                      title: 'Só para o admin da patota',
                      message:
                          'A retrospectiva fica disponível apenas para quem administra a patota.',
                    )
                  : _content(groupId),
        ),
      ]),
    );
  }

  Widget _content(String groupId) {
    final query = (groupId: groupId, playerId: _playerId, year: _year);
    return ref.watch(retrospectiveProvider(query)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Message(
            icon: Icons.error_outline_rounded,
            title: 'Não foi possível carregar',
            message: extractDioError(e),
            onRetry: () => ref.invalidate(retrospectiveProvider(query)),
          ),
          data: (r) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(retrospectiveProvider(query)),
            child: _Loaded(
              r: r,
              onPlayer: (id) => setState(() => _playerId = id),
              onYear: (y) => setState(() => _year = y),
            ),
          ),
        );
  }
}

class _Loaded extends StatelessWidget {
  final PlayerRetrospective r;
  final ValueChanged<String> onPlayer;
  final ValueChanged<int> onYear;

  const _Loaded(
      {required this.r, required this.onPlayer, required this.onYear});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final stories = storiesFor(r);
    final players = [
      if (!r.players.any((p) => p.playerId == r.player.playerId)) r.player,
      ...r.players,
    ];
    final years = r.availableYears.isEmpty
        ? [r.period.year ?? DateTime.now().year]
        : r.availableYears;
    final resumo = stories.where((s) => s.id == StoryId.resumo).firstOrNull;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: r.player.playerId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Jogador'),
              items: [
                for (final p in players)
                  DropdownMenuItem(
                      value: p.playerId,
                      child: Text('${p.name} · ${p.games}',
                          overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (id) {
                if (id != null && id != r.player.playerId) onPlayer(id);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<int>(
              initialValue: r.period.year ?? years.first,
              decoration: const InputDecoration(labelText: 'Temporada'),
              items: [
                for (final y in years)
                  DropdownMenuItem(value: y, child: Text('$y'))
              ],
              onChanged: (y) {
                if (y != null && y != r.period.year) onYear(y);
              },
            ),
          ),
        ]),
        const SizedBox(height: 18),
        if (r.games == 0)
          _Message(
            icon: Icons.sports_soccer_outlined,
            title: 'Sem jogos',
            message: '${r.player.shortName} não jogou em ${r.period.label}.',
          )
        else ...[
          Text('A temporada de ${r.player.name}', style: text.titleLarge),
          const SizedBox(height: 4),
          Text(
            '${plural(r.totalGames, 'jogo', 'jogos')} da patota, ${r.player.shortName} esteve em ${r.games}. '
            '${stories.length} stories.${r.period.isPartial ? ' Temporada em andamento: os números ainda podem mudar.' : ''}',
            style: text.bodyMedium?.copyWith(color: context.appTextSecondary),
          ),
          const SizedBox(height: 16),
          if (resumo != null)
            Center(
              child: GestureDetector(
                onTap: () => _open(context),
                child: SizedBox(
                  width: 220,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: RetroStoryCard(r: r, story: resumo, still: true),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => _open(context),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Ver stories'),
          ),
        ],
      ],
    );
  }

  void _open(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => RetrospectiveStoriesPage(r: r)),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const _Message(
      {required this.icon,
      required this.title,
      required this.message,
      this.onRetry});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40, color: context.appTextSecondary),
          const SizedBox(height: 12),
          Text(title, style: text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message,
              style: text.bodyMedium?.copyWith(color: context.appTextSecondary),
              textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: onRetry, child: const Text('Tentar de novo')),
          ],
        ]),
      ),
    );
  }
}

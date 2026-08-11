import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../domain/entities/conquista_models.dart';
import '../providers/conquistas_provider.dart';
import '../widgets/conquistas_section.dart';
import '../../../../shared/presentation/widgets/app_page_header.dart';

class ConquistasPage extends ConsumerStatefulWidget {
  const ConquistasPage({super.key});

  @override
  ConsumerState<ConquistasPage> createState() => _ConquistasPageState();
}

class _ConquistasPageState extends ConsumerState<ConquistasPage> {
  bool _showGroup = false;
  String? _expandedPlayerId;

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    final groupId = account?.activeGroupId ?? activePlayer?.groupId;
    final playerId = activePlayer?.playerId ?? account?.activePlayerId;
    final isAdmin =
        groupId != null && (account?.isGroupAdmin(groupId) ?? false);

    return Scaffold(
      body: Column(
        children: [
          AppPageHeader(
            title: 'Conquistas',
            subtitle: 'Marcos, feitos e títulos',
            icon: Icons.emoji_events_outlined,
            footer: account?.userId.isNotEmpty == true
                ? AppPageHeaderActionBar(actions: [
                    if (account?.userId.isNotEmpty == true)
                      AppPageHeaderButton(
                        label: 'Meu perfil',
                        icon: Icons.account_circle_outlined,
                        onPressed: () =>
                            context.push('/app/profile/${account!.userId}'),
                      ),
                  ])
                : null,
          ),
          Expanded(
            child: groupId == null || groupId.isEmpty
                ? const _MessageState(
                    icon: Icons.groups_outlined,
                    title: 'Selecione uma patota',
                    message:
                        'As conquistas são calculadas dentro de cada patota.',
                  )
                : RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(groupConquistasProvider(groupId)),
                    child: ref.watch(groupConquistasProvider(groupId)).when(
                          loading: () => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          error: (error, _) => ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(24),
                            children: [
                              _MessageState(
                                icon: Icons.error_outline_rounded,
                                title: 'Não foi possível carregar',
                                message: extractDioError(error),
                              ),
                            ],
                          ),
                          data: (data) {
                            final own = data.players
                                .where((item) => item.playerId == playerId)
                                .firstOrNull;
                            return ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets.fromLTRB(16, 16, 16, 36),
                              children: [
                                _HeroCard(
                                  season: data.season,
                                  player: own,
                                  groupName: activePlayer?.groupName,
                                ),
                                if (isAdmin) ...[
                                  const SizedBox(height: 14),
                                  SegmentedButton<bool>(
                                    segments: const [
                                      ButtonSegment(
                                        value: false,
                                        icon:
                                            Icon(Icons.person_outline_rounded),
                                        label: Text('Minhas'),
                                      ),
                                      ButtonSegment(
                                        value: true,
                                        icon: Icon(Icons.groups_outlined),
                                        label: Text('Patota'),
                                      ),
                                    ],
                                    selected: {_showGroup},
                                    onSelectionChanged: (value) => setState(
                                        () => _showGroup = value.first),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                if (_showGroup && isAdmin)
                                  _GroupOverview(
                                    data: data,
                                    expandedPlayerId: _expandedPlayerId,
                                    onExpand: (id) => setState(() {
                                      _expandedPlayerId =
                                          _expandedPlayerId == id ? null : id;
                                    }),
                                  )
                                else if (own != null)
                                  ConquistasSection(
                                      player: own, season: data.season)
                                else
                                  const _MessageState(
                                    icon: Icons.emoji_events_outlined,
                                    title: 'Sem histórico ainda',
                                    message:
                                        'Jogue partidas pela patota para começar a desbloquear conquistas.',
                                  ),
                              ],
                            );
                          },
                        ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final int season;
  final PlayerConquistas? player;
  final String? groupName;
  const _HeroCard({this.player, required this.season, this.groupName});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.appBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: .12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.workspace_premium_rounded,
                  color: Theme.of(context).colorScheme.primary, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(groupName ?? 'Sua patota',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          )),
                  const SizedBox(height: 2),
                  Text('Temporada $season',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.appTextSecondary,
                          )),
                ],
              ),
            ),
            Column(
              children: [
                Text('${player?.totalDesbloqueadas ?? 0}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w900,
                        )),
                Text('desbloqueadas',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.appTextSecondary,
                          fontSize: 9,
                        )),
              ],
            ),
          ],
        ),
      );
}

class _GroupOverview extends StatelessWidget {
  final GroupConquistas data;
  final String? expandedPlayerId;
  final ValueChanged<String> onExpand;
  const _GroupOverview({
    required this.data,
    required this.expandedPlayerId,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final ranked = [...data.players]
      ..sort((a, b) => b.totalDesbloqueadas.compareTo(a.totalDesbloqueadas));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('JOGADORES · ${ranked.length}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.appTextSecondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                )),
        const SizedBox(height: 9),
        Container(
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.appBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: ranked.map((player) {
              final expanded = player.playerId == expandedPlayerId;
              final badges = topConquistas(player);
              return Column(
                children: [
                  InkWell(
                    onTap: () => onExpand(player.playerId),
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: .12),
                            foregroundColor:
                                Theme.of(context).colorScheme.primary,
                            child: Text(
                              player.playerName.isEmpty
                                  ? '?'
                                  : player.playerName[0].toUpperCase(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(player.playerName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        )),
                                if (badges.isEmpty)
                                  Text('Sem conquistas ainda',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: context.appTextSecondary,
                                          ))
                                else
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: badges
                                          .map((item) => ConquistaBadge(
                                              conquista: item, compact: true))
                                          .toList(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (player.userId != null &&
                              player.userId!.isNotEmpty)
                            IconButton(
                              tooltip: 'Ver perfil',
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  context.push('/app/profile/${player.userId}'),
                              icon: const Icon(Icons.open_in_new_rounded,
                                  size: 17),
                            ),
                          Text('${player.totalDesbloqueadas}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w900)),
                          Icon(
                            expanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            color: context.appTextSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (expanded)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: context.appSurfaceSubtle,
                      child: ConquistasSection(
                        player: player,
                        season: data.season,
                        showHeading: false,
                      ),
                    ),
                  if (player != ranked.last)
                    Divider(height: 1, color: context.appSeparator),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: context.appTextSecondary),
              const SizedBox(height: 12),
              Text(title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      )),
              const SizedBox(height: 5),
              Text(message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appTextSecondary,
                      )),
            ],
          ),
        ),
      );
}

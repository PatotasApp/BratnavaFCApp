import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/app_page_header.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../../../shared/presentation/widgets/prototype_ui.dart';
import '../../../group_settings/presentation/providers/group_settings_provider.dart';
import '../../../matches/presentation/pages/matches_page.dart'
    show LinkedPollStrip;
import '../../../team_colors/domain/entities/team_color.dart';
import '../../../team_colors/presentation/providers/team_colors_provider.dart';
import '../../domain/entities/championship_enums.dart';
import '../../domain/entities/championship_models.dart';
import '../championship_ui_text.dart';
import '../providers/championship_provider.dart';
import '../widgets/championship_draw_panel.dart';
import '../widgets/championship_live_game.dart';
import '../widgets/championship_replays_section.dart';
import '../widgets/championship_stage_header.dart';
import '../widgets/championship_swap_teams.dart';

class ChampionshipDetailPage extends ConsumerStatefulWidget {
  const ChampionshipDetailPage({super.key, required this.championshipId});

  final String championshipId;

  @override
  ConsumerState<ChampionshipDetailPage> createState() =>
      _ChampionshipDetailPageState();
}

/// Campeonato em etapas, como a partida: Criado → Presença → Sorteio → Times →
/// Jogos → Pós-jogo → Final. Cada etapa mostra só o que importa nela.
class _ChampionshipDetailPageState
    extends ConsumerState<ChampionshipDetailPage> {
  Timer? _polling;
  String _gamesTab = 'Jogo';

  @override
  void initState() {
    super.initState();
    _polling = Timer.periodic(const Duration(seconds: 5), (_) {
      final provider = championshipDetailsProvider(widget.championshipId);
      if (ref.read(provider).details?.status == ChampionshipStatus.inProgress) {
        ref.read(provider.notifier).load(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _polling?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = championshipDetailsProvider(widget.championshipId);
    final state = ref.watch(provider);
    final isAdmin = ref.watch(championshipIsAdminProvider);
    final groupId = ref.watch(championshipGroupIdProvider);
    final icons =
        GroupIcons.from(ref.watch(groupSettingsProvider(groupId)).valueOrNull);
    final notifier = ref.read(provider.notifier);
    final details = state.details;
    final stage = details == null ? null : championshipStageOf(details);
    final liveGame =
        stage == ChampionshipStage.games ? details!.currentGame : null;

    return Column(
      children: [
        AppPageHeader(
          title: details?.name ?? 'Campeonato',
          subtitle: details == null
              ? 'Carregando detalhes'
              : '${DateFormat('dd/MM · HH:mm').format(details.playedAt)} · '
                  '${details.placeName}',
          icon: Icons.emoji_events_outlined,
        ),
        Expanded(
          child: state.loading && details == null
              ? const Center(child: CircularProgressIndicator())
              : details == null
                  ? _ErrorView(
                      message: state.error ?? 'Campeonato não encontrado.',
                      retry: notifier.load,
                    )
                  : Stack(
                      children: [
                        RefreshIndicator(
                          onRefresh: notifier.load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                            children: _spaced([
                              if (state.error != null)
                                _MessageCard(message: state.error!),
                              ChampionshipStageHeader(stage: stage!),
                              ..._stageContent(
                                context,
                                details: details,
                                stage: stage,
                                state: state,
                                isAdmin: isAdmin,
                                notifier: notifier,
                                icons: icons,
                                groupId: groupId,
                              ),
                            ]),
                          ),
                        ),
                        // "Registrar gol" é a bolinha no canto, como na partida.
                        if (isAdmin && liveGame != null)
                          Positioned(
                            right: 20,
                            bottom: 24,
                            child: FloatingActionButton(
                              heroTag: 'championship-quick-goal',
                              tooltip: 'Registrar gol',
                              backgroundColor: AppColors.onDark,
                              foregroundColor: AppColors.infoLight,
                              onPressed: state.mutating
                                  ? null
                                  : () => showChampionshipGoalSheet(
                                        context,
                                        details: details,
                                        game: liveGame,
                                        notifier: notifier,
                                        icons: icons,
                                      ),
                              child: const Icon(Icons.sports_soccer_rounded,
                                  size: 30),
                            ),
                          ),
                      ],
                    ),
        ),
      ],
    );
  }

  List<Widget> _stageContent(
    BuildContext context, {
    required ChampionshipDetails details,
    required ChampionshipStage stage,
    required ChampionshipDetailsState state,
    required bool isAdmin,
    required ChampionshipDetailsNotifier notifier,
    required GroupIcons icons,
    required String groupId,
  }) {
    final admin = isAdmin
        ? _AdminActions(
            details: details,
            stage: stage,
            mutating: state.mutating,
            notifier: notifier,
          )
        : null;
    final linked = LinkedPollStrip(
      groupId: groupId,
      linkedPollId: details.linkedPollId,
      isAdmin: isAdmin,
      onLink: (pollId) => notifier.setLinkedPoll(pollId),
      onUnlink: () => notifier.setLinkedPoll(null),
    );
    final presence = _PresenceSection(
      details: details,
      isAdmin: isAdmin,
      notifier: notifier,
      icons: icons,
    );
    final teamsByPosition = _TeamsByPosition(details: details, icons: icons);
    final replays = ChampionshipReplaysSection(
      details: details,
      groupId: groupId,
    );

    return switch (stage) {
      ChampionshipStage.created => [
          _Overview(details: details),
          linked,
          if (admin != null) admin
        ],
      ChampionshipStage.acceptation => [
          _Overview(details: details),
          linked,
          presence,
          if (admin != null) admin,
        ],
      ChampionshipStage.draw => [
          if (isAdmin)
            ChampionshipDrawPanel(
              details: details,
              notifier: notifier,
              icons: icons,
              onAddGuest: () => _addGuest(context, details, notifier),
            )
          else ...[
            const _MessageCard(
                message: 'O admin está sorteando os times. Já já eles '
                    'aparecem aqui.'),
            presence,
          ],
          if (admin != null) admin,
        ],
      ChampionshipStage.teams => [
          _TeamsSection(
            details: details,
            isAdmin: isAdmin,
            notifier: notifier,
            icons: icons,
          ),
          if (admin != null) admin,
        ],
      ChampionshipStage.games => [
          PrototypeSegmented(
            items: const ['Jogo', 'Classificação'],
            value: _gamesTab,
            onChanged: (value) => setState(() => _gamesTab = value),
            semanticLabel: 'Jogo ou classificação',
          ),
          if (_gamesTab == 'Jogo')
            ..._gameTab(context, details, state, isAdmin, notifier, icons)
          else ...[
            if (details.standings.isNotEmpty)
              _StandingsSection(details: details),
            if (details.topScorers.isNotEmpty || details.topAssists.isNotEmpty)
              _HighlightsSection(details: details, icons: icons),
            _GamesList(details: details),
            _TeamsSection(
              details: details,
              isAdmin: isAdmin,
              notifier: notifier,
              icons: icons,
            ),
          ],
          if (details.currentGame == null)
            if (admin != null) admin,
        ],
      ChampionshipStage.postGame => [
          if (details.standings.isNotEmpty) _StandingsSection(details: details),
          if (details.rules.mvpMode != ChampionshipMvpMode.none)
            _MvpSection(details: details, notifier: notifier),
          if (details.topScorers.isNotEmpty || details.topAssists.isNotEmpty)
            _HighlightsSection(details: details, icons: icons),
          teamsByPosition,
          replays,
          if (admin != null) admin,
        ],
      ChampionshipStage.finalized => [
          teamsByPosition,
          if (details.standings.isNotEmpty) _StandingsSection(details: details),
          if (details.rules.mvpMode != ChampionshipMvpMode.none)
            _MvpSection(details: details, notifier: notifier),
          if (details.topScorers.isNotEmpty || details.topAssists.isNotEmpty)
            _HighlightsSection(details: details, icons: icons),
          replays,
          if (admin != null) admin,
        ],
      ChampionshipStage.cancelled => [_Overview(details: details)],
    };
  }

  List<Widget> _gameTab(
    BuildContext context,
    ChampionshipDetails details,
    ChampionshipDetailsState state,
    bool isAdmin,
    ChampionshipDetailsNotifier notifier,
    GroupIcons icons,
  ) {
    final current = details.currentGame;
    if (current != null) {
      return [
        ChampionshipLiveGame(
          details: details,
          game: current,
          isAdmin: isAdmin,
          notifier: notifier,
          icons: icons,
          nextMatchup: nextMatchupDuringGame(details),
          onEndGame: () => _endGame(context, details, current, notifier),
        ),
      ];
    }
    return [
      _NextMatchupCard(
        details: details,
        suggestion: state.nextGame,
        isAdmin: isAdmin,
        mutating: state.mutating,
        onStart: notifier.createSuggestedGame,
      ),
      if (details.games.isNotEmpty) _GamesList(details: details),
    ];
  }
}

/// Coloca o espaço padrão entre os cards de uma etapa.
List<Widget> _spaced(List<Widget> children) => [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        children[i],
      ],
    ];

/// "Próximo confronto" com um jogo em andamento: no fica quem ganha é o
/// vencedor contra o primeiro da fila; nos outros formatos, os dois da fila.
String? nextMatchupDuringGame(ChampionshipDetails details) {
  final waiting = details.waitingTeamIds;
  final current = details.currentGame;
  if (waiting.isEmpty || current == null) return null;
  String name(String id) => details.teamById(id)?.name ?? 'Time';
  if (details.rules.format == ChampionshipFormat.winnerStays ||
      waiting.length == 1) {
    return 'vencedor de ${name(current.teamAId)} × ${name(current.teamBId)} '
        'contra ${name(waiting.first)}';
  }
  return '${name(waiting[0])} × ${name(waiting[1])}';
}

class _NextMatchupCard extends StatelessWidget {
  const _NextMatchupCard({
    required this.details,
    required this.suggestion,
    required this.isAdmin,
    required this.mutating,
    required this.onStart,
  });

  final ChampionshipDetails details;
  final NextGameSuggestion? suggestion;
  final bool isAdmin;
  final bool mutating;
  final Future<bool> Function() onStart;

  @override
  Widget build(BuildContext context) {
    final next = suggestion;
    final theme = Theme.of(context);
    if (next == null) {
      return _MessageCard(
        message: championshipNoCurrentGameLine(
          details,
          const AsyncData(null),
          isAdmin: isAdmin,
        ),
      );
    }
    final teamA = details.teamById(next.teamAId);
    final teamB = details.teamById(next.teamBId);
    return PrototypeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            details.games.isEmpty
                ? '1º CONFRONTO'
                : 'PRÓXIMO CONFRONTO · JOGO ${details.games.length + 1}',
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _MatchupTeam(team: teamA)),
              Text('×',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w900)),
              Expanded(child: _MatchupTeam(team: teamB)),
            ],
          ),
          const SizedBox(height: 8),
          Text(next.reason,
              textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          if (next.waitingTeamIds.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Depois: vencedor contra '
              '${details.teamById(next.waitingTeamIds.first)?.name ?? 'Time'}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (isAdmin) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                key: const ValueKey('start-game'),
                onPressed: mutating ? null : onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Iniciar partida'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MatchupTeam extends StatelessWidget {
  const _MatchupTeam({required this.team});
  final ChampionshipTeam? team;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          _TeamColor(hex: team?.colorHex, size: 34),
          const SizedBox(height: 6),
          Text(team?.name ?? 'Time',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          Text('${team?.playerIds.length ?? 0} jogadores',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

class _GamesList extends StatelessWidget {
  const _GamesList({required this.details});
  final ChampionshipDetails details;

  @override
  Widget build(BuildContext context) => PrototypeCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionTitle(
              icon: Icons.sports_soccer_rounded,
              title: 'Jogos',
              trailing: Text('${details.games.length}'),
            ),
            if (details.games.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Nenhum jogo ainda.'),
              ),
            for (final game in details.games.reversed)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Text('${game.order}'),
                title: Text('${_teamName(details, game.teamAId)} '
                    '${game.teamAGoals} × ${game.teamBGoals} '
                    '${_teamName(details, game.teamBId)}'),
                trailing: game.status == ChampionshipGameStatus.inProgress
                    ? const PrototypeBadge(
                        label: 'AO VIVO', tone: PrototypeBadgeTone.danger)
                    : null,
              ),
          ],
        ),
      );
}

/// Jogadores agrupados por time, um time por aba, na ordem da colocação
/// (1º, 2º, 3º…). Substitui a lista de presenças depois dos jogos.
class _TeamsByPosition extends StatefulWidget {
  const _TeamsByPosition({required this.details, required this.icons});
  final ChampionshipDetails details;
  final GroupIcons icons;

  @override
  State<_TeamsByPosition> createState() => _TeamsByPositionState();
}

class _TeamsByPositionState extends State<_TeamsByPosition> {
  int _index = 0;

  List<(int, ChampionshipTeam)> get _ordered {
    final details = widget.details;
    int positionOf(ChampionshipTeam team) =>
        team.finalPosition ??
        details.standings
            .where((s) => s.teamId == team.id)
            .map((s) => s.position)
            .firstOrNull ??
        99;
    final teams = [...details.teams]
      ..sort((a, b) => positionOf(a).compareTo(positionOf(b)));
    return [for (final team in teams) (positionOf(team), team)];
  }

  String _rankIcon(int position) => switch (position) {
        1 => widget.icons.rank1,
        2 => widget.icons.rank2,
        3 => widget.icons.rank3,
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final ordered = _ordered;
    if (ordered.isEmpty) return const SizedBox.shrink();
    final index = _index.clamp(0, ordered.length - 1);
    final (position, team) = ordered[index];
    final players = team.playerIds
        .map((id) => widget.details.playerById(id))
        .whereType<ChampionshipPlayer>()
        .toList();
    return PrototypeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(icon: Icons.groups_outlined, title: 'Times'),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < ordered.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: ValueKey('team-tab-$i'),
                      avatar: _TeamColor(hex: ordered[i].$2.colorHex, size: 16),
                      label: Text(ordered[i].$1 == 99
                          ? ordered[i].$2.name
                          : '${ordered[i].$1}º ${ordered[i].$2.name}'),
                      selected: i == index,
                      onSelected: (_) => setState(() => _index = i),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_rankIcon(position).isNotEmpty) ...[
                renderGroupIcon(_rankIcon(position), size: 20),
                const SizedBox(width: 6),
              ],
              Text(
                position == 99 ? team.name : '$positionº lugar · ${team.name}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          for (final player in players)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: PlayerNameWithIcon(
                name: player.name,
                icons: widget.icons,
                isGoalkeeper: player.isGoalkeeper,
              ),
            ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.details});
  final ChampionshipDetails details;

  @override
  Widget build(BuildContext context) => PrototypeCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionTitle(
              icon: Icons.info_outline_rounded,
              title: 'Visão geral',
              trailing: PrototypeBadge(
                label: championshipStatusLabel(details.status),
              ),
            ),
            const SizedBox(height: 10),
            Text('${DateFormat('dd/MM/yyyy · HH:mm').format(details.playedAt)}'
                ' · ${details.placeName}'),
            const SizedBox(height: 8),
            // Só o resumo por extenso: os selos repetiam a mesma coisa.
            Text(championshipRulesSummary(details.rules)),
          ],
        ),
      );
}

class _PresenceSection extends StatelessWidget {
  const _PresenceSection({
    required this.details,
    required this.isAdmin,
    required this.notifier,
    required this.icons,
  });

  final ChampionshipDetails details;
  final bool isAdmin;
  final ChampionshipDetailsNotifier notifier;
  final GroupIcons icons;

  @override
  Widget build(BuildContext context) {
    final response = details.myInviteResponse;
    return PrototypeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            icon: Icons.how_to_reg_outlined,
            title: 'Presenças',
            trailing: Text('${details.players.length} jogadores'),
          ),
          if (response != null &&
              details.status == ChampionshipStatus.acceptation) ...[
            const SizedBox(height: 12),
            SegmentedButton<ChampionshipInviteResponse>(
              segments: const [
                ButtonSegment(
                  value: ChampionshipInviteResponse.accepted,
                  label: Text('Vou'),
                  icon: Icon(Icons.check_rounded),
                ),
                ButtonSegment(
                  value: ChampionshipInviteResponse.rejected,
                  label: Text('Não vou'),
                  icon: Icon(Icons.close_rounded),
                ),
              ],
              selected: response == ChampionshipInviteResponse.none
                  ? <ChampionshipInviteResponse>{}
                  : {response},
              emptySelectionAllowed: true,
              onSelectionChanged: (values) {
                if (values.contains(ChampionshipInviteResponse.accepted)) {
                  notifier.acceptMyInvite();
                } else if (values
                    .contains(ChampionshipInviteResponse.rejected)) {
                  notifier.rejectMyInvite();
                }
              },
            ),
          ],
          const SizedBox(height: 8),
          for (final player in details.players)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(_inviteIcon(player.inviteResponse)),
              title: PlayerNameWithIcon(
                name: player.name,
                icons: icons,
                isGoalkeeper: player.isGoalkeeper,
              ),
              subtitle: player.isGuest ? const Text('Convidado') : null,
              trailing: isAdmin &&
                      (details.status == ChampionshipStatus.acceptation ||
                          details.status == ChampionshipStatus.teamDraw)
                  // Como na aceitação da partida: os dois botões na linha,
                  // escondendo o que já é a resposta atual.
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (player.inviteResponse !=
                            ChampionshipInviteResponse.rejected)
                          _InviteButton(
                            icon: Icons.close,
                            tooltip: 'Recusar ${player.name}',
                            onTap: () => notifier.setInvite(
                              player.playerId,
                              accepted: false,
                            ),
                          ),
                        if (player.inviteResponse !=
                            ChampionshipInviteResponse.accepted) ...[
                          const SizedBox(width: 6),
                          _InviteButton(
                            icon: Icons.check,
                            tooltip: 'Confirmar ${player.name}',
                            onTap: () => notifier.setInvite(
                              player.playerId,
                              accepted: true,
                            ),
                          ),
                        ],
                      ],
                    )
                  : Text(_inviteLabel(player.inviteResponse)),
            ),
        ],
      ),
    );
  }
}

class _TeamsSection extends ConsumerStatefulWidget {
  const _TeamsSection({
    required this.details,
    required this.isAdmin,
    required this.notifier,
    required this.icons,
  });

  final ChampionshipDetails details;
  final bool isAdmin;
  final ChampionshipDetailsNotifier notifier;
  final GroupIcons icons;

  @override
  ConsumerState<_TeamsSection> createState() => _TeamsSectionState();
}

/// Etapa Times, como a aba Times da formação da partida: troca 2 jogadores de
/// times diferentes (levando o papel de goleiro, sem time com 2 goleiros),
/// encaixa quem ficou sem time e edita nome e cor.
class _TeamsSectionState extends ConsumerState<_TeamsSection> {
  ChampionshipDetails get details => widget.details;

  bool get _canEditTeams =>
      widget.isAdmin &&
      details.status != ChampionshipStatus.finalized &&
      details.status != ChampionshipStatus.cancelled;

  bool get _canSwap =>
      widget.isAdmin &&
      (details.status == ChampionshipStatus.teamDraw ||
          details.status == ChampionshipStatus.inProgress);

  @override
  Widget build(BuildContext context) {
    final unassigned = details.unassignedPlayers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrototypeCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionTitle(
                icon: Icons.groups_outlined,
                title: 'Times',
                trailing: _canEditTeams
                    ? TextButton.icon(
                        onPressed: () async {
                          final message =
                              await widget.notifier.drawTeamColors();
                          if (message != null && context.mounted) {
                            _showMessage(context, message);
                          }
                        },
                        icon: const Icon(Icons.palette_outlined, size: 18),
                        label: const Text('Sortear cores'),
                      )
                    : null,
              ),
              if (_canSwap) ...[
                const SizedBox(height: 4),
                Text(
                  'Toque num jogador e depois num de outro time para trocar '
                  'os dois (o goleiro vai junto).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              SwappableTeams(
                teams: [
                  for (final team in details.teams)
                    SwapTeam(
                      id: team.id,
                      name: team.name,
                      colorHex: team.colorHex,
                      playerIds: team.playerIds,
                      isGoalkeeper: (id) =>
                          details.playerById(id)?.isGoalkeeper == true,
                      subtitle: [
                        if (team.colorHex == null) 'sem cor',
                        if (!team.playerIds.any((id) =>
                            details.playerById(id)?.isGoalkeeper == true))
                          'sem goleiro',
                      ].join(' · ').ifEmptyNull,
                      trailing: _canEditTeams
                          ? IconButton(
                              tooltip: 'Editar nome e cor',
                              onPressed: () =>
                                  _editTeam(context, team, widget.notifier),
                              icon: const Icon(Icons.edit_outlined),
                            )
                          : null,
                    ),
                ],
                playerName: (id) => _playerName(details, id),
                icons: widget.icons,
                enabled: _canSwap,
                onSwap: widget.notifier.swapPlayers,
              ),
            ],
          ),
        ),
        if (unassigned.isNotEmpty && details.teams.isNotEmpty) ...[
          const SizedBox(height: 12),
          PrototypeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionTitle(
                  icon: Icons.person_search_outlined,
                  title: 'Sem time',
                  trailing: Text('${unassigned.length}'),
                ),
                const SizedBox(height: 4),
                Text('Escolha o time de cada um.',
                    style: Theme.of(context).textTheme.bodySmall),
                for (final player in unassigned) ...[
                  const SizedBox(height: 10),
                  PlayerNameWithIcon(
                    name: player.name,
                    icons: widget.icons,
                    isGoalkeeper: player.isGoalkeeper,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final team in details.teams)
                        ActionChip(
                          avatar: _TeamColor(hex: team.colorHex, size: 16),
                          label: Text(team.name),
                          onPressed: widget.isAdmin
                              ? () => widget.notifier
                                  .assignPlayerTeam(player.playerId, team.id)
                              : null,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StandingsSection extends StatelessWidget {
  const _StandingsSection({required this.details});
  final ChampionshipDetails details;

  @override
  Widget build(BuildContext context) => PrototypeCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle(
              icon: Icons.leaderboard_outlined,
              title: 'Classificação',
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 18,
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Time')),
                  DataColumn(label: Text('J')),
                  DataColumn(label: Text('V')),
                  DataColumn(label: Text('E')),
                  DataColumn(label: Text('D')),
                  DataColumn(label: Text('SG')),
                  DataColumn(label: Text('Pts')),
                  DataColumn(label: Text('PPG')),
                ],
                rows: [
                  for (final row in details.standings)
                    DataRow(cells: [
                      DataCell(Text('${row.position}')),
                      DataCell(Text(_teamName(details, row.teamId))),
                      DataCell(Text('${row.played}')),
                      DataCell(Text('${row.wins}')),
                      DataCell(Text('${row.draws}')),
                      DataCell(Text('${row.losses}')),
                      DataCell(Text('${row.goalDifference}')),
                      DataCell(Text('${row.points}')),
                      DataCell(Text(row.pointsPerGame.toStringAsFixed(2))),
                    ]),
                ],
              ),
            ),
          ],
        ),
      );
}

class _HighlightsSection extends StatelessWidget {
  const _HighlightsSection({required this.details, required this.icons});
  final ChampionshipDetails details;
  final GroupIcons icons;

  @override
  Widget build(BuildContext context) => PrototypeCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle(
              icon: Icons.auto_awesome_outlined,
              title: 'Destaques',
            ),
            const SizedBox(height: 8),
            if (details.topScorers.isNotEmpty) ...[
              Text('Artilharia', style: Theme.of(context).textTheme.titleSmall),
              for (final item in details.topScorers)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: renderGroupIcon(icons.goal, size: 16),
                  title: Text(_playerName(details, item.playerId)),
                  trailing: Text('${item.total} gols'),
                ),
            ],
            if (details.topAssists.isNotEmpty) ...[
              Text('Assistências',
                  style: Theme.of(context).textTheme.titleSmall),
              for (final item in details.topAssists)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: renderGroupIcon(icons.assist, size: 16),
                  title: Text(_playerName(details, item.playerId)),
                  trailing: Text('${item.total} assistências'),
                ),
            ],
          ],
        ),
      );
}

class _MvpSection extends StatelessWidget {
  const _MvpSection({required this.details, required this.notifier});
  final ChampionshipDetails details;
  final ChampionshipDetailsNotifier notifier;

  @override
  Widget build(BuildContext context) => PrototypeCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle(icon: Icons.star_outline, title: 'MVP'),
            if (details.mvpPlayerIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                  'Eleito: ${details.mvpPlayerIds.map((id) => _playerName(details, id)).join(', ')}'),
            ],
            if (details.myVotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final vote in details.myVotes)
                Text('Seu voto: ${_playerName(details, vote.votedPlayerId)}'
                    '${vote.gameId == null ? '' : ' · jogo ${_gameOrder(details, vote.gameId!)}'}'),
            ],
            if (details.canVote) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _showVoteDialog(context, details, notifier),
                icon: const Icon(Icons.how_to_vote_outlined),
                label: const Text('Votar no MVP'),
              ),
            ],
          ],
        ),
      );
}

class _AdminActions extends StatelessWidget {
  const _AdminActions({
    required this.details,
    required this.stage,
    required this.mutating,
    required this.notifier,
  });
  final ChampionshipDetails details;
  final ChampionshipStage stage;
  final bool mutating;
  final ChampionshipDetailsNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];
    switch (stage) {
      case ChampionshipStage.created:
        actions.add(FilledButton(
          onPressed: notifier.openAcceptation,
          child: const Text('Abrir confirmação de presença'),
        ));
        actions.add(OutlinedButton(
          onPressed: notifier.cancel,
          child: const Text('Cancelar campeonato'),
        ));
      case ChampionshipStage.acceptation:
        actions.add(FilledButton.icon(
          onPressed: notifier.openTeamDraw,
          icon: const Icon(Icons.shuffle_rounded),
          label: const Text('Ir para o sorteio'),
        ));
        actions.add(OutlinedButton(
          onPressed: () => _addGuest(context, details, notifier),
          child: const Text('Adicionar convidado'),
        ));
      case ChampionshipStage.draw:
        break;
      case ChampionshipStage.teams:
        actions.add(FilledButton.icon(
          onPressed: notifier.start,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Iniciar campeonato'),
        ));
      case ChampionshipStage.games:
        actions.add(FilledButton.icon(
          onPressed: () => _finish(context, details, notifier),
          icon: const Icon(Icons.flag_outlined),
          label: const Text('Encerrar campeonato'),
        ));
      case ChampionshipStage.postGame:
        actions.add(FilledButton(
          onPressed: () => notifier.finalize(
            externalDecisionTeamOrder:
                details.standings.map((row) => row.teamId).toList(),
          ),
          child: const Text('Finalizar com a classificação atual'),
        ));
      case ChampionshipStage.finalized:
      case ChampionshipStage.cancelled:
        break;
    }
    final previous = _previousStepLabel(stage);
    if (previous != null &&
        !(stage == ChampionshipStage.games && details.games.isNotEmpty)) {
      actions.add(TextButton.icon(
        onPressed: () => _stepBack(context, stage, notifier),
        icon: const Icon(Icons.undo_rounded),
        label: Text(previous),
      ));
    }
    if (actions.isEmpty) return const SizedBox.shrink();
    return PrototypeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Administração',
          ),
          const SizedBox(height: 12),
          if (mutating) const LinearProgressIndicator(),
          for (final action in actions) ...[
            const SizedBox(height: 8),
            IgnorePointer(ignoring: mutating, child: action),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title, this.trailing});
  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (trailing != null) trailing!,
        ],
      );
}

class _TeamColor extends StatelessWidget {
  const _TeamColor({required this.hex, this.size = 28});
  final String? hex;
  final double size;

  @override
  Widget build(BuildContext context) {
    final normalized = hex?.replaceFirst('#', '');
    final value =
        normalized == null ? null : int.tryParse('FF$normalized', radix: 16);
    final outline = Theme.of(context).colorScheme.outline;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: value == null ? null : Color(value),
        shape: BoxShape.circle,
        border: Border.all(color: outline.withValues(alpha: .5)),
      ),
      child: value == null
          ? Icon(
              Icons.format_color_reset_outlined,
              size: size * .55,
              color: outline,
            )
          : null,
    );
  }
}

void _showMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 6)),
    );

/// `PATCH /{id}/teams/{teamId}` com as cores ativas da patota (v5).
Future<void> _editTeam(
  BuildContext context,
  ChampionshipTeam team,
  ChampionshipDetailsNotifier notifier,
) async {
  final controller = TextEditingController(text: team.name);
  String? colorId = team.colorId;
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final colorsAsync = ref.watch(teamColorsProvider(notifier.groupId));
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final colors = (colorsAsync.valueOrNull ?? const <TeamColor>[])
                .where((color) => color.isActive || color.id == colorId)
                .toList();
            final known =
                colorId == null || colors.any((color) => color.id == colorId);
            return AlertDialog(
              title: const Text('Editar time'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  const SizedBox(height: 12),
                  if (colorsAsync.isLoading)
                    const LinearProgressIndicator()
                  else
                    DropdownButtonFormField<String?>(
                      initialValue: known ? colorId : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Cor',
                        helperText: 'Cores ativas da patota.',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Sem cor'),
                        ),
                        for (final color in colors)
                          DropdownMenuItem<String?>(
                            value: color.id,
                            child: Row(
                              children: [
                                _TeamColor(hex: color.hexValue, size: 18),
                                const SizedBox(width: 8),
                                Expanded(child: Text(color.name)),
                              ],
                            ),
                          ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => colorId = value),
                    ),
                  if (colorsAsync.hasError)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Não foi possível carregar as cores.'),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    ),
  );
  final name = controller.text.trim();
  // Sem dispose aqui: o diálogo ainda está animando a saída e usa o campo; o
  // controller sai junto com o diálogo pelo coletor.
  if (saved != true || name.isEmpty) return;
  final ok = await notifier.updateTeam(team.id, name: name, colorId: colorId);
  if (ok && context.mounted) _showMessage(context, 'Time atualizado.');
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.retry});
  final String message;
  final Future<void> Function() retry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: retry, child: const Text('Tentar de novo')),
            ],
          ),
        ),
      );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => PrototypeCard(child: Text(message));
}

/// Etapa anterior de cada etapa para o `POST /{id}/step-back`.
String? _previousStepLabel(ChampionshipStage stage) => switch (stage) {
      ChampionshipStage.acceptation => 'Voltar para Criado',
      ChampionshipStage.draw => 'Voltar para a presença',
      ChampionshipStage.teams => 'Voltar para o sorteio',
      ChampionshipStage.games => 'Voltar para os times',
      ChampionshipStage.postGame => 'Voltar para os jogos',
      ChampionshipStage.finalized => 'Reabrir (voltar para o MVP)',
      ChampionshipStage.created || ChampionshipStage.cancelled => null,
    };

String _previousStepWarning(ChampionshipStage stage) => switch (stage) {
      ChampionshipStage.acceptation =>
        'A lista de presença é apagada. Você pode abri-la de novo depois.',
      ChampionshipStage.draw =>
        'Volta para a confirmação de presença. Os goleiros marcados continuam.',
      ChampionshipStage.teams =>
        'Os times são desfeitos para sortear de novo. Os goleiros continuam.',
      ChampionshipStage.games =>
        'Só é possível antes do 1º jogo. As regras voltam a poder ser editadas.',
      ChampionshipStage.postGame =>
        'Os votos de MVP são descartados e dá para criar mais jogos.',
      ChampionshipStage.finalized =>
        'O campeão e as estatísticas deixam de contar até finalizar de novo.',
      _ => '',
    };

Future<void> _stepBack(
  BuildContext context,
  ChampionshipStage stage,
  ChampionshipDetailsNotifier notifier,
) async {
  final label = _previousStepLabel(stage);
  if (label == null) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('$label?'),
      content: Text(_previousStepWarning(stage)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(label),
        ),
      ],
    ),
  );
  if (confirmed == true) await notifier.stepBack();
}

Future<void> _addGuest(
  BuildContext context,
  ChampionshipDetails details,
  ChampionshipDetailsNotifier notifier,
) async {
  final already = {for (final player in details.players) player.playerId};
  final nameController = TextEditingController();
  var isGoalkeeper = false;
  int? stars;
  String? error;

  // Como na partida: convidado novo pelo nome, goleiro e nota. Embaixo, os
  // convidados que já jogaram na patota, para quem volta não ser duplicado.
  final result = await showDialog<Object>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => Consumer(
        builder: (context, ref, _) {
          final playersAsync =
              ref.watch(championshipGroupPlayersProvider(notifier.groupId));
          final returning = (playersAsync.valueOrNull ?? const [])
              .where((p) => p.isGuest && !already.contains(p.id))
              .toList();
          return AlertDialog(
            title: const Text('Adicionar convidado'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Nome do convidado',
                        hintText: 'Ex: Zé da Pelada',
                        errorText: error,
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Goleiro'),
                      value: isGoalkeeper,
                      onChanged: (value) =>
                          setDialogState(() => isGoalkeeper = value),
                    ),
                    Text('Nota (opcional)',
                        style: Theme.of(context).textTheme.labelMedium),
                    Row(
                      children: [
                        for (var star = 1; star <= 5; star++)
                          IconButton(
                            tooltip: '$star estrela${star > 1 ? 's' : ''}',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setDialogState(
                                () => stars = stars == star ? null : star),
                            icon: Icon(
                              star <= (stars ?? 0)
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: AppColors.amber500,
                            ),
                          ),
                      ],
                    ),
                    if (returning.isNotEmpty) ...[
                      const Divider(height: 24),
                      Text('Ou um convidado que já jogou',
                          style: Theme.of(context).textTheme.labelMedium),
                      for (final player in returning)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.person_add_alt_outlined),
                          title: Text(player.name),
                          onTap: () => Navigator.pop(context, player.id),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    setDialogState(() => error = 'Nome é obrigatório.');
                    return;
                  }
                  Navigator.pop(context, true);
                },
                child: const Text('Adicionar'),
              ),
            ],
          );
        },
      ),
    ),
  );
  final name = nameController.text.trim();
  // Sem dispose aqui: o diálogo ainda está animando a saída e usa o campo; o
  // controller sai junto com o diálogo pelo coletor.
  if (result is String) {
    await notifier.addGuest(result);
  } else if (result == true) {
    await notifier.addNewGuest(
      name: name,
      isGoalkeeper: isGoalkeeper,
      starRating: stars,
    );
  }
}

/// `POST /{id}/finish`. Depois dele vem a votação do MVP (se houver) e o
/// admin finaliza.
Future<void> _finish(
  BuildContext context,
  ChampionshipDetails details,
  ChampionshipDetailsNotifier notifier,
) async {
  final hasMvp = details.rules.mvpMode != ChampionshipMvpMode.none;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Encerrar campeonato?'),
      content: Text(hasMvp
          ? 'Não dá para criar novos jogos depois. Em seguida abre a votação '
              'do MVP e, por fim, você finaliza o campeonato.'
          : 'Não dá para criar novos jogos depois. Em seguida você finaliza '
              'o campeonato.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Voltar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Encerrar campeonato'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  final ok = await notifier.finish();
  if (ok && hasMvp && context.mounted) {
    _showMessage(context, 'Votação do MVP aberta.');
  }
}

Future<void> _endGame(
  BuildContext context,
  ChampionshipDetails details,
  ChampionshipGame game,
  ChampionshipDetailsNotifier notifier,
) async {
  String? winner;
  if (game.teamAGoals == game.teamBGoals) {
    winner = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quem venceu o desempate?'),
        content:
            const Text('Informe a decisão externa por pênaltis ou sorteio.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          for (final teamId in [game.teamAId, game.teamBId])
            FilledButton(
              onPressed: () => Navigator.pop(context, teamId),
              child: Text(_teamName(details, teamId)),
            ),
        ],
      ),
    );
    if (winner == null) return;
  }
  await notifier.endGame(game.id, externalWinnerTeamId: winner);
}

Future<void> _showVoteDialog(
  BuildContext context,
  ChampionshipDetails details,
  ChampionshipDetailsNotifier notifier,
) async {
  final players = details.players
      .where((player) =>
          player.inviteResponse == ChampionshipInviteResponse.accepted)
      .toList();
  if (players.isEmpty) return;
  var playerId = players.first.playerId;
  String? gameId = details.rules.mvpMode == ChampionshipMvpMode.perGame &&
          details.games.isNotEmpty
      ? details.games.first.id
      : null;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Votar no MVP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (details.rules.mvpMode == ChampionshipMvpMode.perGame)
              DropdownButtonFormField<String>(
                initialValue: gameId,
                decoration: const InputDecoration(labelText: 'Jogo'),
                items: [
                  for (final game in details.games)
                    DropdownMenuItem(
                        value: game.id, child: Text('Jogo ${game.order}')),
                ],
                onChanged: (value) => setDialogState(() => gameId = value),
              ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: playerId,
              decoration: const InputDecoration(labelText: 'Jogador'),
              items: [
                for (final player in players)
                  DropdownMenuItem(
                      value: player.playerId, child: Text(player.name)),
              ],
              onChanged: (value) => setDialogState(() => playerId = value!),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar voto')),
        ],
      ),
    ),
  );
  if (confirmed == true) await notifier.vote(playerId, gameId: gameId);
}

String _playerName(ChampionshipDetails details, String id) =>
    details.playerById(id)?.name ?? 'Jogador';

String _teamName(ChampionshipDetails details, String id) =>
    details.teamById(id)?.name ?? 'Time';

int _gameOrder(ChampionshipDetails details, String id) {
  for (final game in details.games) {
    if (game.id == id) return game.order;
  }
  return 0;
}

IconData _inviteIcon(ChampionshipInviteResponse response) => switch (response) {
      ChampionshipInviteResponse.none => Icons.help_outline,
      ChampionshipInviteResponse.rejected => Icons.cancel_outlined,
      ChampionshipInviteResponse.accepted => Icons.check_circle_outline,
    };

String _inviteLabel(ChampionshipInviteResponse response) => switch (response) {
      ChampionshipInviteResponse.none => 'Sem resposta',
      ChampionshipInviteResponse.rejected => 'Recusou',
      ChampionshipInviteResponse.accepted => 'Confirmado',
    };

/// Botão de presença por jogador, igual ao da aceitação da partida
/// (`.proto-icon-btn`: 44×44, borda neutra, ícone em text-secondary).
class _InviteButton extends StatelessWidget {
  const _InviteButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PrototypeLayout.controlRadius),
          child: Container(
            width: PrototypeLayout.minimumTouchTarget,
            height: PrototypeLayout.minimumTouchTarget,
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate900 : AppColors.lightCard,
              borderRadius:
                  BorderRadius.circular(PrototypeLayout.controlRadius),
              border: Border.all(
                  color: isDark ? AppColors.slate700 : AppColors.lightBorder),
            ),
            child: Icon(
              icon,
              size: 15,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

extension on String {
  String? get ifEmptyNull => isEmpty ? null : this;
}

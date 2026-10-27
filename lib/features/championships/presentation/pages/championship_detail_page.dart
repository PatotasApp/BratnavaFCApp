import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/presentation/widgets/app_page_header.dart';
import '../../../../shared/presentation/widgets/prototype_ui.dart';
import '../../domain/entities/championship_enums.dart';
import '../../domain/entities/championship_models.dart';
import '../championship_ui_text.dart';
import '../providers/championship_provider.dart';

class ChampionshipDetailPage extends ConsumerStatefulWidget {
  const ChampionshipDetailPage({super.key, required this.championshipId});

  final String championshipId;

  @override
  ConsumerState<ChampionshipDetailPage> createState() =>
      _ChampionshipDetailPageState();
}

class _ChampionshipDetailPageState
    extends ConsumerState<ChampionshipDetailPage> {
  Timer? _polling;

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
    final details = state.details;

    return Column(
      children: [
        AppPageHeader(
          title: details?.name ?? 'Campeonato',
          subtitle: details == null
              ? 'Carregando detalhes'
              : championshipStatusLabel(details.status),
          icon: Icons.emoji_events_outlined,
        ),
        Expanded(
          child: state.loading && details == null
              ? const Center(child: CircularProgressIndicator())
              : details == null
                  ? _ErrorView(
                      message: state.error ?? 'Campeonato não encontrado.',
                      retry: ref.read(provider.notifier).load,
                    )
                  : RefreshIndicator(
                      onRefresh: ref.read(provider.notifier).load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                        children: [
                          if (state.error != null) ...[
                            _MessageCard(message: state.error!),
                            const SizedBox(height: 12),
                          ],
                          _Overview(details: details),
                          const SizedBox(height: 12),
                          _PresenceSection(
                            details: details,
                            isAdmin: isAdmin,
                            notifier: ref.read(provider.notifier),
                          ),
                          if (details.teams.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _TeamsSection(
                              details: details,
                              isAdmin: isAdmin,
                              notifier: ref.read(provider.notifier),
                            ),
                          ],
                          if (details.status == ChampionshipStatus.inProgress ||
                              details.games.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _LiveSection(
                              details: details,
                              suggestion: state.nextGame,
                              isAdmin: isAdmin,
                              notifier: ref.read(provider.notifier),
                            ),
                          ],
                          if (details.standings.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _StandingsSection(details: details),
                          ],
                          if (details.topScorers.isNotEmpty ||
                              details.topAssists.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _HighlightsSection(details: details),
                          ],
                          if (details.rules.mvpMode !=
                                  ChampionshipMvpMode.none &&
                              (details.status == ChampionshipStatus.postGame ||
                                  details.status ==
                                      ChampionshipStatus.finalized)) ...[
                            const SizedBox(height: 12),
                            _MvpSection(
                              details: details,
                              notifier: ref.read(provider.notifier),
                            ),
                          ],
                          if (isAdmin) ...[
                            const SizedBox(height: 12),
                            _AdminActions(
                              details: details,
                              mutating: state.mutating,
                              notifier: ref.read(provider.notifier),
                            ),
                          ],
                        ],
                      ),
                    ),
        ),
      ],
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
            Text(championshipRulesSummary(details.rules)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final badge in details.ruleBadges)
                  PrototypeBadge(label: badge),
              ],
            ),
          ],
        ),
      );
}

class _PresenceSection extends StatelessWidget {
  const _PresenceSection({
    required this.details,
    required this.isAdmin,
    required this.notifier,
  });

  final ChampionshipDetails details;
  final bool isAdmin;
  final ChampionshipDetailsNotifier notifier;

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
              title: Text(player.name),
              subtitle: player.isGuest ? const Text('Convidado') : null,
              trailing: isAdmin &&
                      details.status == ChampionshipStatus.acceptation
                  ? PopupMenuButton<bool>(
                      tooltip: 'Alterar presença',
                      onSelected: (accepted) => notifier.setInvite(
                        player.playerId,
                        accepted: accepted,
                      ),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: true, child: Text('Confirmar')),
                        PopupMenuItem(value: false, child: Text('Recusar')),
                      ],
                    )
                  : Text(_inviteLabel(player.inviteResponse)),
            ),
        ],
      ),
    );
  }
}

class _TeamsSection extends StatelessWidget {
  const _TeamsSection({
    required this.details,
    required this.isAdmin,
    required this.notifier,
  });

  final ChampionshipDetails details;
  final bool isAdmin;
  final ChampionshipDetailsNotifier notifier;

  @override
  Widget build(BuildContext context) => PrototypeCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle(icon: Icons.groups_outlined, title: 'Times'),
            const SizedBox(height: 8),
            for (final team in details.teams)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                leading: _TeamColor(hex: team.colorHex),
                title: Text(team.name),
                subtitle: Text('${team.playerIds.length} jogadores'),
                trailing: team.finalPosition == null
                    ? null
                    : Text('${team.finalPosition}º'),
                children: [
                  for (final playerId in team.playerIds)
                    ListTile(
                      dense: true,
                      title: Text(_playerName(details, playerId)),
                      leading: Icon(
                        details.playerById(playerId)?.isGoalkeeper == true
                            ? Icons.sports_handball
                            : Icons.person_outline,
                      ),
                      trailing: isAdmin &&
                              details.status == ChampionshipStatus.inProgress
                          ? TextButton(
                              onPressed: () => notifier.setGoalkeeper(
                                team.id,
                                playerId,
                              ),
                              child: const Text('Goleiro'),
                            )
                          : null,
                    ),
                ],
              ),
          ],
        ),
      );
}

class _LiveSection extends StatelessWidget {
  const _LiveSection({
    required this.details,
    required this.suggestion,
    required this.isAdmin,
    required this.notifier,
  });

  final ChampionshipDetails details;
  final NextGameSuggestion? suggestion;
  final bool isAdmin;
  final ChampionshipDetailsNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final current = details.currentGame;
    return PrototypeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            icon: Icons.sports_soccer_rounded,
            title: current == null ? 'Jogos' : 'Ao vivo',
            trailing: current == null
                ? Text('${details.games.length} jogos')
                : const PrototypeBadge(
                    label: 'AO VIVO',
                    tone: PrototypeBadgeTone.danger,
                  ),
          ),
          if (current != null) ...[
            const SizedBox(height: 14),
            _Score(details: details, game: current),
            if (current.goals.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final goal in current.goals)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.sports_soccer, size: 20),
                  title: Text(_playerName(details, goal.scorerPlayerId)),
                  subtitle: Text([
                    if (goal.assistPlayerId != null)
                      'Assistência: ${_playerName(details, goal.assistPlayerId!)}',
                    if (goal.isOwnGoal) 'Gol contra',
                  ].join(' · ')),
                  trailing: isAdmin
                      ? IconButton(
                          tooltip: 'Remover gol',
                          onPressed: () => notifier.deleteGoal(
                            current.id,
                            goal.id,
                          ),
                          icon: const Icon(Icons.delete_outline),
                        )
                      : null,
                ),
            ],
            if (isAdmin) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _showGoalDialog(
                      context,
                      details,
                      current,
                      notifier,
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Registrar gol'),
                  ),
                  OutlinedButton(
                    onPressed: () => _endGame(
                      context,
                      details,
                      current,
                      notifier,
                    ),
                    child: const Text('Encerrar jogo'),
                  ),
                ],
              ),
            ],
          ] else if (suggestion != null) ...[
            const SizedBox(height: 12),
            Text(suggestion!.reason),
            const SizedBox(height: 8),
            Text('${_teamName(details, suggestion!.teamAId)} × '
                '${_teamName(details, suggestion!.teamBId)}'),
            if (isAdmin) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: notifier.createSuggestedGame,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Começar próximo jogo'),
              ),
            ],
          ],
          if (details.waitingTeamIds.isNotEmpty) ...[
            const Divider(height: 26),
            Text(
                'Fila: ${details.waitingTeamIds.map((id) => _teamName(details, id)).join(' → ')}'),
          ],
          if (details.games.isNotEmpty) ...[
            const Divider(height: 26),
            for (final game in details.games.reversed.take(5))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${_teamName(details, game.teamAId)} '
                    '${game.teamAGoals} × ${game.teamBGoals} '
                    '${_teamName(details, game.teamBId)}'),
                trailing: Text('Jogo ${game.order}'),
              ),
          ],
        ],
      ),
    );
  }
}

class _Score extends StatelessWidget {
  const _Score({required this.details, required this.game});
  final ChampionshipDetails details;
  final ChampionshipGame game;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              _teamName(details, game.teamAId),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Text(
            '${game.teamAGoals}  ×  ${game.teamBGoals}',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          Expanded(
            child: Text(
              _teamName(details, game.teamBId),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      );
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
  const _HighlightsSection({required this.details});
  final ChampionshipDetails details;

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
    required this.mutating,
    required this.notifier,
  });
  final ChampionshipDetails details;
  final bool mutating;
  final ChampionshipDetailsNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];
    switch (details.status) {
      case ChampionshipStatus.created:
        actions.add(FilledButton(
          onPressed: notifier.openAcceptation,
          child: const Text('Abrir confirmação de presença'),
        ));
        actions.add(OutlinedButton(
          onPressed: notifier.cancel,
          child: const Text('Cancelar campeonato'),
        ));
      case ChampionshipStatus.acceptation:
        actions.add(FilledButton(
          onPressed: () => _drawTeams(context, notifier),
          child: const Text('Sortear e definir times'),
        ));
        actions.add(OutlinedButton(
          onPressed: () => _addGuest(context, notifier),
          child: const Text('Adicionar convidado cadastrado'),
        ));
      case ChampionshipStatus.teamDraw:
        actions.add(FilledButton.icon(
          onPressed: notifier.start,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Iniciar campeonato'),
        ));
      case ChampionshipStatus.inProgress:
        if (details.currentGame == null) {
          actions.add(OutlinedButton(
            onPressed: notifier.finish,
            child: const Text('Encerrar campeonato'),
          ));
        }
      case ChampionshipStatus.postGame:
        actions.add(FilledButton(
          onPressed: () => notifier.finalize(
            externalDecisionTeamOrder:
                details.standings.map((row) => row.teamId).toList(),
          ),
          child: const Text('Finalizar com a classificação atual'),
        ));
      case ChampionshipStatus.finalized:
      case ChampionshipStatus.cancelled:
        break;
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
  const _TeamColor({required this.hex});
  final String hex;

  @override
  Widget build(BuildContext context) {
    final normalized = hex.replaceFirst('#', '');
    final color = Color(int.tryParse('FF$normalized', radix: 16) ?? 0xFF777777);
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
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

Future<void> _drawTeams(
  BuildContext context,
  ChampionshipDetailsNotifier notifier,
) async {
  var teamCount = 3;
  final count = await showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sortear times'),
      content: StatefulBuilder(
        builder: (context, setDialogState) => DropdownButtonFormField<int>(
          initialValue: teamCount,
          decoration: const InputDecoration(labelText: 'Quantidade de times'),
          items: [
            for (var value = 2; value <= 6; value++)
              DropdownMenuItem(value: value, child: Text('$value times')),
          ],
          onChanged: (value) {
            if (value != null) setDialogState(() => teamCount = value);
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(context, teamCount),
            child: const Text('Sortear')),
      ],
    ),
  );
  if (count == null || !context.mounted) return;
  final suggestion = await notifier.drawTeams(count);
  if (suggestion == null || !context.mounted) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirmar times'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final team in suggestion.teams)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${team.name}: ${team.playerIds.length} jogadores'),
            ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar times')),
      ],
    ),
  );
  if (confirmed == true) await notifier.defineTeams(suggestion);
}

Future<void> _addGuest(
  BuildContext context,
  ChampionshipDetailsNotifier notifier,
) async {
  final controller = TextEditingController();
  final id = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Adicionar convidado'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'ID do jogador cadastrado',
          helperText: 'O contrato aceita somente jogador já cadastrado.',
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Adicionar')),
      ],
    ),
  );
  controller.dispose();
  if (id?.isNotEmpty == true) await notifier.addGuest(id!);
}

Future<void> _showGoalDialog(
  BuildContext context,
  ChampionshipDetails details,
  ChampionshipGame game,
  ChampionshipDetailsNotifier notifier,
) async {
  final eligible = details.players
      .where((player) =>
          player.teamId == game.teamAId || player.teamId == game.teamBId)
      .toList();
  if (eligible.isEmpty) return;
  var scorer = eligible.first.playerId;
  String? assist;
  var ownGoal = false;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Registrar gol'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: scorer,
              decoration: const InputDecoration(labelText: 'Autor'),
              items: [
                for (final player in eligible)
                  DropdownMenuItem(
                      value: player.playerId, child: Text(player.name)),
              ],
              onChanged: (value) => setDialogState(() => scorer = value!),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              initialValue: assist,
              decoration: const InputDecoration(labelText: 'Assistência'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Sem assistência')),
                for (final player in eligible)
                  DropdownMenuItem(
                      value: player.playerId, child: Text(player.name)),
              ],
              onChanged: (value) => setDialogState(() => assist = value),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Gol contra'),
              value: ownGoal,
              onChanged: (value) =>
                  setDialogState(() => ownGoal = value ?? false),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar')),
        ],
      ),
    ),
  );
  if (result == true) {
    await notifier.addGoal(
      gameId: game.id,
      scorerPlayerId: scorer,
      assistPlayerId: assist,
      isOwnGoal: ownGoal,
    );
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

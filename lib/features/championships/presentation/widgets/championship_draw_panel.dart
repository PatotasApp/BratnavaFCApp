import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../../../shared/presentation/widgets/prototype_ui.dart';
import '../../../team_colors/domain/entities/team_color.dart';
import '../../../team_colors/presentation/providers/team_colors_provider.dart';
import '../../domain/entities/championship_models.dart';
import '../providers/championship_provider.dart';

/// Métodos da formação da partida, com os ids que a API espera.
const kChampionshipDrawStrategies = [
  (
    id: 1,
    label: 'Manual',
    description: 'Monte do seu jeito',
    icon: Icons.pan_tool_outlined
  ),
  (
    id: 2,
    label: 'Aleatório',
    description: 'Sorteio rápido',
    icon: Icons.shuffle_rounded
  ),
  (
    id: 3,
    label: 'Algoritmo',
    description: 'Mais equilibrado',
    icon: Icons.auto_awesome_rounded
  ),
  (
    id: 4,
    label: 'Por vitórias',
    description: 'Usa o histórico',
    icon: Icons.emoji_events_outlined
  ),
  (
    id: 5,
    label: 'Por perfil',
    description: 'Combina estilos',
    icon: Icons.groups_outlined
  ),
];

enum _DrawTab {
  gerar('Gerar'),
  cores('Cores'),
  opcoes('Opções');

  const _DrawTab(this.label);
  final String label;
}

/// Etapa Sorteio, como a formação da partida: primeiro os goleiros, depois as
/// abas Gerar · Cores · Opções. Escolher uma opção salva os times e leva para
/// a etapa Times; nada de modal de confirmação.
class ChampionshipDrawPanel extends ConsumerStatefulWidget {
  const ChampionshipDrawPanel({
    super.key,
    required this.details,
    required this.notifier,
    required this.icons,
    required this.onAddGuest,
  });

  final ChampionshipDetails details;
  final ChampionshipDetailsNotifier notifier;
  final GroupIcons icons;
  final VoidCallback onAddGuest;

  @override
  ConsumerState<ChampionshipDrawPanel> createState() =>
      _ChampionshipDrawPanelState();
}

class _ChampionshipDrawPanelState extends ConsumerState<ChampionshipDrawPanel> {
  _DrawTab _tab = _DrawTab.gerar;
  int _strategy = 3;
  late int _teamCount;
  bool _includeGoalkeepers = true;
  List<String?> _colorIds = [];
  ChampionshipDrawOptions? _draw;
  int _selected = 0;

  ChampionshipDetails get _details => widget.details;

  int get _minTeams => _details.rules.minimumTeams;

  @override
  void initState() {
    super.initState();
    final confirmed = _details.confirmedPlayers.length;
    _teamCount = _minTeams.clamp(2, confirmed < 2 ? 2 : confirmed);
  }

  List<TeamColor> _activeColors() =>
      (ref.watch(teamColorsProvider(widget.notifier.groupId)).valueOrNull ??
              const <TeamColor>[])
          .where((color) => color.isActive)
          .toList();

  void _ensureColors(List<TeamColor> colors) {
    if (_colorIds.length == _teamCount) return;
    final used = _colorIds.whereType<String>().toSet();
    final free = colors.where((c) => !used.contains(c.id)).map((c) => c.id);
    final next = [..._colorIds.take(_teamCount)];
    final iterator = free.iterator;
    while (next.length < _teamCount) {
      next.add(iterator.moveNext() ? iterator.current : null);
    }
    _colorIds = next;
  }

  void _pickColor(int team, String colorId) => setState(() {
        // Como na partida: escolher a cor de outro time troca as duas de lugar.
        final other = _colorIds.indexOf(colorId);
        if (other >= 0 && other != team) _colorIds[other] = _colorIds[team];
        _colorIds[team] = colorId;
      });

  void _shuffleColors(List<TeamColor> colors) => setState(() {
        final shuffled = [...colors]..shuffle();
        _colorIds = [
          for (var i = 0; i < _teamCount; i++)
            i < shuffled.length ? shuffled[i].id : null,
        ];
      });

  Future<void> _generate() async {
    final draw = await widget.notifier.drawTeamOptions(
      teamCount: _teamCount,
      strategyType: _strategy,
      includeGoalkeepers: _includeGoalkeepers,
      colorIds: _colorIds,
    );
    if (draw == null || !mounted) return;
    setState(() {
      _draw = draw;
      _selected = 0;
      _tab = _DrawTab.opcoes;
    });
    if (draw.message != null) _snack(draw.message!);
  }

  Future<void> _useOption(ChampionshipDrawOption option) async {
    await widget.notifier.defineTeams(DefineChampionshipTeams(
      teams: option.teams,
    ));
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final colors = _activeColors();
    _ensureColors(colors);
    final mutating =
        ref.watch(championshipDetailsProvider(_details.id)).mutating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GoalkeepersCard(
          details: _details,
          icons: widget.icons,
          onToggle: (player) => widget.notifier
              .setPlayerGoalkeeper(player.playerId, !player.isGoalkeeper),
          onAddGuest: widget.onAddGuest,
        ),
        const SizedBox(height: 12),
        PrototypeSegmented(
          items: _DrawTab.values.map((t) => t.label).toList(),
          value: _tab.label,
          onChanged: (label) => setState(
              () => _tab = _DrawTab.values.firstWhere((t) => t.label == label)),
          semanticLabel: 'Etapa do sorteio',
        ),
        const SizedBox(height: 12),
        switch (_tab) {
          _DrawTab.gerar => _generatorTab(mutating),
          _DrawTab.cores => _colorsTab(colors),
          _DrawTab.opcoes => _optionsTab(mutating),
        },
      ],
    );
  }

  Widget _generatorTab(bool mutating) {
    final confirmed = _details.confirmedPlayers.length;
    final maxTeams = confirmed < 2 ? 2 : (confirmed > 8 ? 8 : confirmed);
    final perTeam = confirmed == 0 ? 0 : (confirmed / _teamCount).floor();
    return PrototypeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Método', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in kChampionshipDrawStrategies)
                    SizedBox(
                      width: width,
                      child: _StrategyCard(
                        label: s.label,
                        description: s.description,
                        icon: s.icon,
                        selected: s.id == _strategy,
                        onTap: () => setState(() => _strategy = s.id),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(child: Text('Quantidade de times')),
              IconButton.outlined(
                tooltip: 'Menos times',
                onPressed: _teamCount > _minTeams
                    ? () => setState(() {
                          _teamCount--;
                          _colorIds = _colorIds.take(_teamCount).toList();
                        })
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '$_teamCount',
                  key: const ValueKey('draw-team-count'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton.outlined(
                tooltip: 'Mais times',
                onPressed: _teamCount < maxTeams
                    ? () => setState(() => _teamCount++)
                    : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          Text(
            '$confirmed confirmados · $perTeam a ${perTeam + (confirmed % _teamCount == 0 ? 0 : 1)} por time',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Incluir goleiros no sorteio'),
            subtitle: const Text('Cada time recebe um goleiro primeiro.'),
            value: _includeGoalkeepers,
            onChanged: (value) => setState(() => _includeGoalkeepers = value),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: mutating ? null : _generate,
              icon: const Icon(Icons.shuffle_rounded),
              label:
                  Text(_strategy == 1 ? 'Montar manualmente' : 'Sortear times'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorsTab(List<TeamColor> colors) {
    if (colors.isEmpty) {
      return const PrototypeCard(
        child: Text('Nenhuma cor ativa. Cadastre em Cores dos times; sem cor, '
            'os times ficam como Time 1, Time 2…'),
      );
    }
    return PrototypeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var team = 0; team < _teamCount; team++) ...[
            Text('Time ${team + 1}',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in colors)
                  ChoiceChip(
                    avatar: _Dot(hex: color.hexValue),
                    label: Text(color.name),
                    selected:
                        _colorIds.length > team && _colorIds[team] == color.id,
                    onSelected: (_) => _pickColor(team, color.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (colors.length < _teamCount)
            Text(
              'Há só ${colors.length} cor(es) ativa(s) para $_teamCount times.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          OutlinedButton.icon(
            onPressed: () => _shuffleColors(colors),
            icon: const Icon(Icons.casino_outlined),
            label: const Text('Sortear cores'),
          ),
          const SizedBox(height: 4),
          FilledButton(
            onPressed: () => setState(() => _tab = _DrawTab.gerar),
            child: const Text('Usar estas cores'),
          ),
        ],
      ),
    );
  }

  Widget _optionsTab(bool mutating) {
    final draw = _draw;
    if (draw == null || draw.options.isEmpty) {
      return const PrototypeCard(
        child: Text('Nenhuma opção gerada ainda. Volte em Gerar e sorteie.'),
      );
    }
    final option = draw.options[_selected.clamp(0, draw.options.length - 1)];
    return PrototypeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Opção anterior',
                onPressed:
                    _selected > 0 ? () => setState(() => _selected--) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('Opção ${_selected + 1} de ${draw.options.length}',
                        style: Theme.of(context).textTheme.titleSmall),
                    if (_strategy != 1)
                      Text(
                        'Diferença de força: '
                        '${(option.strengthDifference * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Próxima opção',
                onPressed: _selected < draw.options.length - 1
                    ? () => setState(() => _selected++)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < option.teams.length; i++)
            _OptionTeam(
              team: option.teams[i],
              hex: _hexOf(option.teams[i].colorId),
              details: _details,
              icons: widget.icons,
            ),
          if (option.unassignedPlayerIds.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Sem time (${option.unassignedPlayerIds.length}): '
              '${option.unassignedPlayerIds.map((id) => _details.playerById(id)?.name ?? 'Jogador').join(', ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: mutating ? null : () => _useOption(option),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Usar esta opção'),
            ),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: mutating ? null : _generate,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Sortear de novo'),
          ),
        ],
      ),
    );
  }

  String? _hexOf(String? colorId) {
    if (colorId == null) return null;
    for (final color in _activeColors()) {
      if (color.id == colorId) return color.hexValue;
    }
    return null;
  }
}

class _GoalkeepersCard extends StatelessWidget {
  const _GoalkeepersCard({
    required this.details,
    required this.icons,
    required this.onToggle,
    required this.onAddGuest,
  });

  final ChampionshipDetails details;
  final GroupIcons icons;
  final ValueChanged<ChampionshipPlayer> onToggle;
  final VoidCallback onAddGuest;

  @override
  Widget build(BuildContext context) {
    final confirmed = details.confirmedPlayers;
    final keepers = confirmed.where((p) => p.isGoalkeeper).length;
    return PrototypeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              renderGroupIcon(icons.goalkeeper, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Goleiros',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Text('$keepers de ${confirmed.length}'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Antes de sortear, toque em quem joga no gol.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final player in confirmed)
                FilterChip(
                  key: ValueKey('gk-chip-${player.playerId}'),
                  avatar: renderGroupIcon(
                    player.isGoalkeeper ? icons.goalkeeper : icons.player,
                    size: 15,
                  ),
                  label: Text(player.name),
                  selected: player.isGoalkeeper,
                  showCheckmark: false,
                  onSelected: (_) => onToggle(player),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAddGuest,
              icon: const Icon(Icons.person_add_alt_outlined),
              label: const Text('Adicionar convidado'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTeam extends StatelessWidget {
  const _OptionTeam({
    required this.team,
    required this.hex,
    required this.details,
    required this.icons,
  });

  final DefineChampionshipTeam team;
  final String? hex;
  final ChampionshipDetails details;
  final GroupIcons icons;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Dot(hex: hex),
                const SizedBox(width: 8),
                Text('${team.name} · ${team.playerIds.length}',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                for (final id in team.playerIds)
                  PlayerNameWithIcon(
                    name: details.playerById(id)?.name ?? 'Jogador',
                    icons: icons,
                    isGoalkeeper: id == team.goalkeeperPlayerId,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
              ],
            ),
          ],
        ),
      );
}

class _StrategyCard extends StatelessWidget {
  const _StrategyCard({
    required this.label,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label. $description',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 88,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected ? scheme.primaryContainer : null,
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800)),
              Text(description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.hex});
  final String? hex;

  @override
  Widget build(BuildContext context) {
    final value = hex == null
        ? null
        : int.tryParse('FF${hex!.replaceFirst('#', '')}', radix: 16);
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: value == null ? null : Color(value),
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}

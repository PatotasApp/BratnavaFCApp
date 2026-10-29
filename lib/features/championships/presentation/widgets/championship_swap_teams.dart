import 'package:flutter/material.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import 'championship_team_field.dart';

/// Um time na lista de troca.
class SwapTeam {
  const SwapTeam({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.playerIds,
    required this.isGoalkeeper,
    this.subtitle,
    this.trailing,
  });

  final String id;
  final String name;
  final String? colorHex;
  final List<String> playerIds;
  final bool Function(String playerId) isGoalkeeper;
  final String? subtitle;
  final Widget? trailing;
}

/// Times em campos com troca de 2 jogadores, igual na etapa Times e nas opções
/// do sorteio: toca num jogador no campo (fica destacado e aparece a faixa
/// fixa), os do mesmo time ficam esmaecidos e não trocam (tocar num deles só
/// muda a seleção), os dos outros times ganham o ⇄. Tocar de novo desmarca.
class SwappableTeams extends StatefulWidget {
  const SwappableTeams({
    super.key,
    required this.teams,
    required this.playerName,
    required this.icons,
    required this.enabled,
    required this.onSwap,
  });

  final List<SwapTeam> teams;
  final String Function(String playerId) playerName;
  final GroupIcons icons;
  final bool enabled;

  /// Troca os dois de time; devolve se deu certo.
  final Future<bool> Function(String first, String second) onSwap;

  @override
  State<SwappableTeams> createState() => _SwappableTeamsState();
}

class _SwappableTeamsState extends State<SwappableTeams> {
  String? _selected;
  ScaffoldMessengerState? _messenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    _messenger?.hideCurrentMaterialBanner();
    super.dispose();
  }

  String? _teamOf(String playerId) {
    for (final team in widget.teams) {
      if (team.playerIds.contains(playerId)) return team.id;
    }
    return null;
  }

  void _select(String? playerId) {
    setState(() => _selected = playerId);
    final messenger = _messenger;
    if (messenger == null) return;
    messenger.hideCurrentMaterialBanner();
    if (playerId == null) return;
    messenger.showMaterialBanner(MaterialBanner(
      key: const ValueKey('swap-banner'),
      content: Text(
        'Toque num jogador de outro time para trocar com '
        '${widget.playerName(playerId)}',
      ),
      leading: const Icon(Icons.swap_horiz_rounded),
      actions: [
        TextButton(
          onPressed: () => _select(null),
          child: const Text('Cancelar'),
        ),
      ],
    ));
  }

  Future<void> _tap(String playerId) async {
    if (!widget.enabled) return;
    final first = _selected;
    if (first == null || first == playerId) {
      _select(first == playerId ? null : playerId);
      return;
    }
    if (_teamOf(first) == _teamOf(playerId)) {
      // Mesmo time não troca: só passa a seleção para ele.
      _select(playerId);
      return;
    }
    _select(null);
    final ok = await widget.onSwap(first, playerId);
    if (ok && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(
            '${widget.playerName(first)} ⇄ ${widget.playerName(playerId)}'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTeam = _selected == null ? null : _teamOf(_selected!);
    // Campos em grade de 2 (1 em tela estreita); com número ímpar de times o
    // último fica centralizado.
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 12.0;
        final width =
            box.maxWidth >= 300 ? (box.maxWidth - gap) / 2 : box.maxWidth;
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: gap,
          runSpacing: 16,
          children: [
            for (final team in widget.teams)
              SizedBox(
                width: width,
                child: _teamCell(context, team, selectedTeam),
              ),
          ],
        );
      },
    );
  }

  Widget _teamCell(BuildContext context, SwapTeam team, String? selectedTeam) {
    final textTheme = Theme.of(context).textTheme;
    final others = selectedTeam != null && selectedTeam != team.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Dot(hex: team.colorHex),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${team.name} · ${team.playerIds.length}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall,
                  ),
                  if (team.subtitle != null)
                    Text(team.subtitle!, style: textTheme.bodySmall),
                ],
              ),
            ),
            if (team.trailing != null) team.trailing!,
          ],
        ),
        const SizedBox(height: 6),
        if (team.playerIds.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('Sem jogadores ainda.'),
          ),
        ChampionshipTeamField(
          key: ValueKey('swap-field-${team.id}'),
          teamName: team.name,
          teamColorHex: team.colorHex,
          showHeader: false,
          icons: widget.icons,
          players: [
            for (final id in team.playerIds)
              FieldPlayerInfo(
                id: id,
                name: widget.playerName(id),
                isGoalkeeper: team.isGoalkeeper(id),
              ),
          ],
          selectedPlayerId: _selected,
          // Outros times: alvo da troca (⇄). Mesmo time: esmaecido.
          swapTargets: others ? team.playerIds.toSet() : const {},
          faded: selectedTeam == team.id
              ? team.playerIds.where((id) => id != _selected).toSet()
              : const {},
          onTapPlayer: widget.enabled ? _tap : null,
        ),
      ],
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

/// Troca 2 jogadores entre times de uma opção do sorteio (local, antes de
/// salvar). O goleiro vai junto e vira o goleiro do novo time; nenhum time
/// fica com 2 goleiros.
List<({List<String> playerIds, String? goalkeeperPlayerId})> swapInOption(
  List<({List<String> playerIds, String? goalkeeperPlayerId})> teams,
  String first,
  String second,
) {
  final a = teams.indexWhere((t) => t.playerIds.contains(first));
  final b = teams.indexWhere((t) => t.playerIds.contains(second));
  if (a < 0 || b < 0 || a == b) return teams;
  final result = [
    for (final t in teams)
      (playerIds: [...t.playerIds], goalkeeperPlayerId: t.goalkeeperPlayerId),
  ];
  final firstWasKeeper = teams[a].goalkeeperPlayerId == first;
  final secondWasKeeper = teams[b].goalkeeperPlayerId == second;
  final aIds = result[a].playerIds;
  final bIds = result[b].playerIds;
  aIds[aIds.indexOf(first)] = second;
  bIds[bIds.indexOf(second)] = first;
  String? keeperA = result[a].goalkeeperPlayerId;
  String? keeperB = result[b].goalkeeperPlayerId;
  if (firstWasKeeper) {
    keeperB = first; // vai junto e substitui o goleiro de lá
    keeperA = secondWasKeeper ? second : null;
  } else if (secondWasKeeper) {
    keeperA = second;
    keeperB = null;
  }
  result[a] = (playerIds: aIds, goalkeeperPlayerId: keeperA);
  result[b] = (playerIds: bIds, goalkeeperPlayerId: keeperB);
  return result;
}

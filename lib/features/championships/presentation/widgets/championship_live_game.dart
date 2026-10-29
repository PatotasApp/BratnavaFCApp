import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../../../shared/presentation/widgets/prototype_ui.dart';
import '../../domain/entities/championship_models.dart';
import '../providers/championship_provider.dart';

// ── Cronômetro do jogo ────────────────────────────────────────────────────────

/// Estado do cronômetro de um jogo. Fica fora da tela (provider por jogo) para
/// não zerar ao sair e voltar. Nunca encerra o jogo: só avisa no fim.
class ChampionshipGameClock {
  const ChampionshipGameClock({
    required this.totalSeconds,
    this.elapsedBefore = Duration.zero,
    this.runningSince,
    this.alerted = false,
  });

  final int totalSeconds;
  final Duration elapsedBefore;
  final DateTime? runningSince;
  final bool alerted;

  bool get running => runningSince != null;
  bool get started => running || elapsedBefore > Duration.zero;

  Duration elapsed(DateTime now) =>
      elapsedBefore +
      (runningSince == null ? Duration.zero : now.difference(runningSince!));

  /// Segundos que faltam; negativo depois do fim (acréscimo).
  int remaining(DateTime now) => totalSeconds - elapsed(now).inSeconds;

  ChampionshipGameClock copyWith({
    int? totalSeconds,
    Duration? elapsedBefore,
    DateTime? runningSince,
    bool clearRunning = false,
    bool? alerted,
  }) =>
      ChampionshipGameClock(
        totalSeconds: totalSeconds ?? this.totalSeconds,
        elapsedBefore: elapsedBefore ?? this.elapsedBefore,
        runningSince: clearRunning ? null : runningSince ?? this.runningSince,
        alerted: alerted ?? this.alerted,
      );
}

class ChampionshipGameClockNotifier
    extends StateNotifier<ChampionshipGameClock> {
  ChampionshipGameClockNotifier(int totalSeconds)
      : super(ChampionshipGameClock(totalSeconds: totalSeconds));

  void play() {
    if (!state.running) state = state.copyWith(runningSince: DateTime.now());
  }

  void pause() {
    if (!state.running) return;
    state = state.copyWith(
      elapsedBefore: state.elapsed(DateTime.now()),
      clearRunning: true,
    );
  }

  void reset() =>
      state = ChampionshipGameClock(totalSeconds: state.totalSeconds);

  void setMinutes(int minutes) => state = state.copyWith(
        totalSeconds: minutes * 60,
        alerted: state.remaining(DateTime.now()) <= 0 &&
            state.elapsed(DateTime.now()).inSeconds >= minutes * 60,
      );

  void markAlerted() => state = state.copyWith(alerted: true);
}

/// Um cronômetro por jogo; o padrão é o tempo de jogo das regras (10 min sem regra).
final championshipGameClockProvider = StateNotifierProvider.family<
    ChampionshipGameClockNotifier, ChampionshipGameClock, (String, int)>(
  (ref, key) => ChampionshipGameClockNotifier(key.$2 * 60),
);

// ── Jogo ao vivo ──────────────────────────────────────────────────────────────

/// Jogo em andamento como a partida: placar, cronômetro, Gol A / Gol B / Jogada
/// bem grandes (para não errar o toque) e os gols do jogo. O "registrar gol" é
/// a bolinha no canto da tela (ver [showChampionshipGoalSheet]).
class ChampionshipLiveGame extends ConsumerStatefulWidget {
  const ChampionshipLiveGame({
    super.key,
    required this.details,
    required this.game,
    required this.isAdmin,
    required this.notifier,
    required this.icons,
    required this.nextMatchup,
    required this.onEndGame,
  });

  final ChampionshipDetails details;
  final ChampionshipGame game;
  final bool isAdmin;
  final ChampionshipDetailsNotifier notifier;
  final GroupIcons icons;
  final String? nextMatchup;
  final VoidCallback onEndGame;

  @override
  ConsumerState<ChampionshipLiveGame> createState() =>
      _ChampionshipLiveGameState();
}

class _ChampionshipLiveGameState extends ConsumerState<ChampionshipLiveGame> {
  String? _publishing;

  Future<void> _publish(String type, String label) async {
    if (_publishing != null) return;
    setState(() => _publishing = type);
    try {
      final ok = await widget.notifier.publishGameEvent(widget.game.id, type);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(type == 'Jogada'
              ? 'Jogada marcada para as câmeras.'
              : '$label: gol somado e replay pedido.'),
        ));
      }
      // Igual à partida: segura os botões um instante contra toque duplo.
      await Future<void>.delayed(const Duration(milliseconds: 900));
    } finally {
      if (mounted) setState(() => _publishing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = widget.details;
    final game = widget.game;
    final teamA = details.teamById(game.teamAId);
    final teamB = details.teamById(game.teamBId);
    final colorA = _color(teamA?.colorHex) ?? AppColors.emerald700;
    final colorB = _color(teamB?.colorHex) ?? AppColors.rose500;
    final nameA = teamA?.name ?? 'Time A';
    final nameB = teamB?.name ?? 'Time B';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrototypeCard(
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.circle,
                      size: 10, color: AppColors.emerald500),
                  const SizedBox(width: 6),
                  Text('Jogo ${game.order} · ao vivo',
                      style: Theme.of(context).textTheme.labelLarge),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _TeamLabel(name: nameA, color: colorA)),
                  Text(
                    '${game.teamAGoals}  ×  ${game.teamBGoals}',
                    key: const ValueKey('live-score'),
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  Expanded(child: _TeamLabel(name: nameB, color: colorB)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ClockCard(
          gameId: game.id,
          defaultMinutes: details.rules.gameEnd.timeLimitMinutes ?? 10,
          canControl: widget.isAdmin,
        ),
        if (widget.isAdmin) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BigButton(
                  key: const ValueKey('btn-gol-a'),
                  label: 'Gol $nameA',
                  color: colorA,
                  icon: Icons.sports_soccer_rounded,
                  height: 96,
                  loading: _publishing == 'GolTimeA',
                  disabled: _publishing != null,
                  onPressed: () => _publish('GolTimeA', 'Gol $nameA'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BigButton(
                  key: const ValueKey('btn-gol-b'),
                  label: 'Gol $nameB',
                  color: colorB,
                  icon: Icons.sports_soccer_rounded,
                  height: 96,
                  loading: _publishing == 'GolTimeB',
                  disabled: _publishing != null,
                  onPressed: () => _publish('GolTimeB', 'Gol $nameB'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _BigButton(
            key: const ValueKey('btn-jogada'),
            label: 'Jogada',
            color: AppColors.infoLight,
            icon: Icons.videocam_rounded,
            height: 72,
            loading: _publishing == 'Jogada',
            disabled: _publishing != null,
            onPressed: () => _publish('Jogada', 'Jogada'),
          ),
        ],
        if (game.goals.isNotEmpty) ...[
          const SizedBox(height: 12),
          PrototypeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Gols do jogo',
                    style: Theme.of(context).textTheme.titleSmall),
                for (final goal in game.goals)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: renderGroupIcon(
                      goal.isOwnGoal ? widget.icons.ownGoal : widget.icons.goal,
                      size: 18,
                    ),
                    title: Text(details.playerById(goal.scorerPlayerId)?.name ??
                        'Jogador'),
                    subtitle: goal.assistPlayerId == null && !goal.isOwnGoal
                        ? null
                        : Text([
                            if (goal.assistPlayerId != null)
                              'Assistência: ${details.playerById(goal.assistPlayerId!)?.name ?? 'Jogador'}',
                            if (goal.isOwnGoal) 'Gol contra',
                          ].join(' · ')),
                    trailing: widget.isAdmin
                        ? IconButton(
                            tooltip: 'Remover gol',
                            onPressed: () =>
                                widget.notifier.deleteGoal(game.id, goal.id),
                            icon: const Icon(Icons.delete_outline),
                          )
                        : null,
                  ),
              ],
            ),
          ),
        ],
        if (widget.nextMatchup != null) ...[
          const SizedBox(height: 12),
          PrototypeCard(
            child: Row(
              children: [
                const Icon(Icons.skip_next_rounded),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('Próximo confronto: ${widget.nextMatchup}')),
              ],
            ),
          ),
        ],
        if (widget.isAdmin) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.rose500),
              onPressed: widget.onEndGame,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Encerrar jogo'),
            ),
          ),
        ],
      ],
    );
  }
}

class _TeamLabel extends StatelessWidget {
  const _TeamLabel({required this.name, required this.color});
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      );
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    required this.height,
    required this.loading,
    required this.disabled,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final IconData icon;
  final double height;
  final bool loading;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Texto legível sobre cores claras (ex.: time Branco).
    final foreground =
        color.computeLuminance() > .6 ? AppColors.slate900 : AppColors.onDark;
    return SizedBox(
      height: height,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: foreground,
          side: color.computeLuminance() > .6
              ? const BorderSide(color: AppColors.slate300)
              : null,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        onPressed: disabled ? null : onPressed,
        child: loading
            ? SizedBox.square(
                dimension: 26,
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: foreground),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 30),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ClockCard extends ConsumerStatefulWidget {
  const _ClockCard({
    required this.gameId,
    required this.defaultMinutes,
    required this.canControl,
  });

  final String gameId;
  final int defaultMinutes;
  final bool canControl;

  @override
  ConsumerState<_ClockCard> createState() => _ClockCardState();
}

class _ClockCardState extends ConsumerState<_ClockCard> {
  Timer? _ticker;

  (String, int) get _key => (widget.gameId, widget.defaultMinutes);

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      final clock = ref.read(championshipGameClockProvider(_key));
      if (clock.running &&
          !clock.alerted &&
          clock.remaining(DateTime.now()) <= 0) {
        ref.read(championshipGameClockProvider(_key).notifier).markAlerted();
        _alertEnd();
      }
      if (clock.running) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Fim do tempo: vibra e toca, mas não encerra o jogo.
  Future<void> _alertEnd() async {
    for (var i = 0; i < 3; i++) {
      await HapticFeedback.vibrate();
      await SystemSound.play(SystemSoundType.alert);
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zerar o cronômetro?'),
        content: const Text('O tempo volta para o início deste jogo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Zerar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(championshipGameClockProvider(_key).notifier).reset();
    }
  }

  Future<void> _editMinutes(int current) async {
    final controller = TextEditingController(text: '$current');
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tempo do jogo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Minutos'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text.trim())),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (minutes != null && minutes > 0) {
      ref
          .read(championshipGameClockProvider(_key).notifier)
          .setMinutes(minutes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clock = ref.watch(championshipGameClockProvider(_key));
    final notifier = ref.read(championshipGameClockProvider(_key).notifier);
    final remaining = clock.remaining(DateTime.now());
    final over = remaining <= 0 && clock.started;
    final shown = remaining.abs();
    final text = '${over && remaining < 0 ? '+' : ''}'
        '${(shown ~/ 60).toString().padLeft(2, '0')}:'
        '${(shown % 60).toString().padLeft(2, '0')}';
    final scheme = Theme.of(context).colorScheme;

    return PrototypeCard(
      child: Column(
        children: [
          if (over)
            Container(
              key: const ValueKey('clock-over'),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.rose500.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Tempo esgotado! Encerre o jogo quando quiser.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.rose500, fontWeight: FontWeight.w800),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  key: const ValueKey('clock-text'),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: over ? AppColors.rose500 : scheme.onSurface,
                      ),
                ),
              ),
              if (widget.canControl)
                IconButton(
                  tooltip: 'Mudar o tempo do jogo',
                  onPressed: () => _editMinutes(clock.totalSeconds ~/ 60),
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Tempo de jogo: ${clock.totalSeconds ~/ 60} min',
                style: Theme.of(context).textTheme.bodySmall),
          ),
          if (widget.canControl) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: clock.running
                      ? FilledButton.tonalIcon(
                          key: const ValueKey('clock-pause'),
                          onPressed: notifier.pause,
                          icon: const Icon(Icons.pause_rounded),
                          label: const Text('Pausar'),
                        )
                      : FilledButton.icon(
                          key: const ValueKey('clock-play'),
                          onPressed: notifier.play,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(clock.started ? 'Continuar' : 'Iniciar'),
                        ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  key: const ValueKey('clock-reset'),
                  onPressed: clock.started ? _confirmReset : null,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Zerar'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Color? _color(String? hex) {
  final value = hex == null
      ? null
      : int.tryParse('FF${hex.replaceFirst('#', '')}', radix: 16);
  return value == null ? null : Color(value);
}

// ── Registrar gol (bolinha no canto) ──────────────────────────────────────────

/// Como o registro rápido da partida: toca no autor, depois na assistência (ou
/// "Sem assistência"). Gol contra opcional.
Future<void> showChampionshipGoalSheet(
  BuildContext context, {
  required ChampionshipDetails details,
  required ChampionshipGame game,
  required ChampionshipDetailsNotifier notifier,
  required GroupIcons icons,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _GoalSheet(
        details: details,
        game: game,
        notifier: notifier,
        icons: icons,
      ),
    );

class _GoalSheet extends StatefulWidget {
  const _GoalSheet({
    required this.details,
    required this.game,
    required this.notifier,
    required this.icons,
  });

  final ChampionshipDetails details;
  final ChampionshipGame game;
  final ChampionshipDetailsNotifier notifier;
  final GroupIcons icons;

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  ChampionshipPlayer? _scorer;
  bool _ownGoal = false;
  bool _saving = false;

  List<ChampionshipPlayer> _team(String teamId) => widget.details.players
      .where((p) => p.teamId == teamId && !p.didNotPlay)
      .toList();

  Future<void> _save(ChampionshipPlayer? assist) async {
    final scorer = _scorer;
    if (scorer == null) return;
    setState(() => _saving = true);
    final started = widget.game.startedAt;
    final ok = await widget.notifier.addGoal(
      gameId: widget.game.id,
      scorerPlayerId: scorer.playerId,
      assistPlayerId: assist?.playerId,
      isOwnGoal: _ownGoal,
      timeSeconds: started == null
          ? null
          : DateTime.now().difference(started).inSeconds.clamp(0, 1 << 30),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  Widget _column(String teamId) {
    final team = widget.details.teamById(teamId);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text((team?.name ?? 'Time').toUpperCase(),
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
          const SizedBox(height: 6),
          for (final player in _team(teamId))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size.fromHeight(46),
                ),
                onPressed:
                    _saving ? null : () => setState(() => _scorer = player),
                child: PlayerNameWithIcon(
                  name: player.name,
                  icons: widget.icons,
                  isGoalkeeper: player.isGoalkeeper,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scorer = _scorer;
    final assistTeam = scorer == null
        ? null
        : _ownGoal
            ? (scorer.teamId == widget.game.teamAId
                ? widget.game.teamBId
                : widget.game.teamAId)
            : scorer.teamId;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  scorer == null
                      ? 'Quem marcou o gol?'
                      : (_ownGoal
                          ? 'Quem ocasionou o gol contra?'
                          : 'Quem deu a assistência?'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (scorer != null)
                IconButton(
                  tooltip: 'Trocar o autor',
                  onPressed: () => setState(() => _scorer = null),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              label: const Text('Gol contra'),
              selected: _ownGoal,
              onSelected: _saving ? null : (v) => setState(() => _ownGoal = v),
            ),
          ),
          const SizedBox(height: 10),
          if (scorer == null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _column(widget.game.teamAId),
                const SizedBox(width: 12),
                _column(widget.game.teamBId),
              ],
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final player in _team(assistTeam!)
                    .where((p) => p.playerId != scorer.playerId))
                  OutlinedButton(
                    onPressed: _saving ? null : () => _save(player),
                    child: PlayerNameWithIcon(
                      name: player.name,
                      icons: widget.icons,
                      isGoalkeeper: player.isGoalkeeper,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
              onPressed: _saving ? null : () => _save(null),
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.remove_circle_outline_rounded),
              label: Text(_ownGoal ? 'Nenhum jogador' : 'Sem assistência'),
            ),
          ],
        ],
      ),
    );
  }
}

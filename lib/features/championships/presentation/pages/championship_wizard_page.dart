import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../shared/presentation/widgets/app_page_header.dart';
import '../../domain/entities/championship_enums.dart';
import '../../domain/entities/championship_models.dart';
import '../../domain/entities/championship_rules.dart';
import '../championship_ui_text.dart';
import '../providers/championship_provider.dart';

class ChampionshipWizardPage extends ConsumerStatefulWidget {
  const ChampionshipWizardPage({super.key});

  @override
  ConsumerState<ChampionshipWizardPage> createState() =>
      _ChampionshipWizardPageState();
}

class _ChampionshipWizardPageState
    extends ConsumerState<ChampionshipWizardPage> {
  final _name = TextEditingController();
  final _place = TextEditingController();
  var _step = 0;
  var _playedAt = DateTime.now().add(const Duration(days: 7));
  var _rules = ChampionshipRules.defaults();
  var _errors = <String>[];

  @override
  void dispose() {
    _name.dispose();
    _place.dispose();
    super.dispose();
  }

  ChampionshipUpsert get _input => ChampionshipUpsert(
        name: _name.text.trim(),
        playedAt: _playedAt,
        placeName: _place.text.trim(),
        rules: _rules,
      );

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _playedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_playedAt),
    );
    if (time == null) return;
    setState(() {
      _playedAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _applyPreset({required int consecutiveWinsLimit}) {
    setState(() {
      _rules = _rules.copyWith(
        format: ChampionshipFormat.winnerStays,
        winnerStays: WinnerStaysRules(
          consecutiveWinsLimit: consecutiveWinsLimit,
          tieRule: WinnerStaysTieRule.longestOnFieldLeaves,
          limitRule: WinnerStaysLimitRule.winnerLeaves,
        ),
        standings: ChampionshipStandingsRules(
          mode: ChampionshipStandingMode.pointsPerGame,
          winPoints: _rules.standings.winPoints,
          drawPoints: _rules.standings.drawPoints,
          tiebreakers: _rules.standings.tiebreakers,
        ),
      );
    });
  }

  void _continue() {
    if (_step < 3) {
      setState(() => _step++);
      return;
    }
    _create();
  }

  Future<void> _create() async {
    final errors = _input.validate();
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }
    final id = await ref.read(championshipListProvider.notifier).create(_input);
    if (!mounted) return;
    if (id != null) {
      context.go('/app/championships/$id');
    } else {
      final message = ref.read(championshipListProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message ?? 'Não foi possível criar.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mutating = ref.watch(championshipListProvider).mutating;
    return Column(
      children: [
        const AppPageHeader(
          title: 'Novo campeonato',
          subtitle: 'Configure o formato e as estatísticas',
          icon: Icons.emoji_events_outlined,
        ),
        Expanded(
          child: Stepper(
            currentStep: _step,
            onStepTapped: (value) => setState(() => _step = value),
            onStepContinue: mutating ? null : _continue,
            onStepCancel: _step == 0 ? null : () => setState(() => _step--),
            controlsBuilder: (context, details) => Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Row(
                children: [
                  FilledButton(
                    onPressed: details.onStepContinue,
                    child: Text(_step == 3 ? 'Criar campeonato' : 'Continuar'),
                  ),
                  if (_step > 0) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text('Voltar'),
                    ),
                  ],
                ],
              ),
            ),
            steps: [
              Step(
                title: const Text('Informações'),
                isActive: _step >= 0,
                content: _buildInformation(),
              ),
              Step(
                title: const Text('Formato'),
                isActive: _step >= 1,
                content: _buildFormat(),
              ),
              Step(
                title: const Text('Estatísticas'),
                isActive: _step >= 2,
                content: _buildStatistics(),
              ),
              Step(
                title: const Text('Revisão'),
                isActive: _step >= 3,
                content: _buildReview(mutating),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInformation() => Column(
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Nome do campeonato',
              hintText: 'Ex.: Copa de sábado',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _place,
            decoration: const InputDecoration(
              labelText: 'Local',
              hintText: 'Ex.: Arena Central',
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Data e hora'),
            subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(_playedAt)),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: _pickDateTime,
          ),
        ],
      );

  Widget _buildFormat() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Comece por um preset'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('Fica quem ganha clássico'),
                onPressed: () => _applyPreset(consecutiveWinsLimit: 0),
              ),
              ActionChip(
                label: const Text('Troca quem ganhou 2'),
                onPressed: () => _applyPreset(consecutiveWinsLimit: 2),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _dropdown(
            label: 'Formato',
            value: _rules.format,
            values: ChampionshipFormat.values,
            text: championshipFormatLabel,
            onChanged: (value) => setState(() {
              _rules = _rules.copyWith(
                format: value,
                winnerStays: value == ChampionshipFormat.winnerStays
                    ? (_rules.winnerStays ??
                        const WinnerStaysRules(
                          consecutiveWinsLimit: 0,
                          tieRule: WinnerStaysTieRule.longestOnFieldLeaves,
                        ))
                    : _rules.winnerStays,
              );
            }),
          ),
          if (_rules.format == ChampionshipFormat.roundRobin ||
              _rules.format == ChampionshipFormat.roundRobinWithFinal) ...[
            const SizedBox(height: 12),
            _dropdown<int>(
              label: 'Turnos',
              value: _rules.roundRobinTurns,
              values: const [1, 2],
              text: (value) => value == 1 ? '1 turno' : '2 turnos',
              onChanged: (value) => setState(
                  () => _rules = _rules.copyWith(roundRobinTurns: value)),
            ),
          ],
          if (_rules.format == ChampionshipFormat.winnerStays) ...[
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey(_rules.winnerStays?.consecutiveWinsLimit),
              initialValue: '${_rules.winnerStays?.consecutiveWinsLimit ?? 0}',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Limite de vitórias seguidas',
                helperText: 'Use 0 para não limitar.',
              ),
              onChanged: (text) => _setWinnerStays(
                limit: int.tryParse(text) ?? -1,
              ),
            ),
            const SizedBox(height: 12),
            _dropdown(
              label: 'Em caso de empate',
              value: _rules.winnerStays!.tieRule,
              values: WinnerStaysTieRule.values,
              text: _tieRuleLabel,
              onChanged: (value) => _setWinnerStays(tieRule: value),
            ),
            if (_rules.winnerStays!.consecutiveWinsLimit > 0) ...[
              const SizedBox(height: 12),
              _dropdown(
                label: 'Ao atingir o limite',
                value: _rules.winnerStays!.limitRule,
                values: WinnerStaysLimitRule.values,
                text: _limitRuleLabel,
                onChanged: (value) => _setWinnerStays(limitRule: value),
              ),
              if (_rules.winnerStays!.limitRule ==
                  WinnerStaysLimitRule.bothLeave)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Com 3 times não dá para saírem os dois; '
                    'sai só o vencedor.',
                  ),
                ),
            ],
          ],
          const SizedBox(height: 16),
          Text('Fim de cada jogo',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _optionalNumber(
                  label: 'Minutos',
                  value: _rules.gameEnd.timeLimitMinutes,
                  onChanged: _setGameEndTime,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _optionalNumber(
                  label: 'Gols',
                  value: _rules.gameEnd.goalLimit,
                  onChanged: _setGameEndGoals,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'O campeonato termina quando o admin tocar em '
            '"Encerrar campeonato".',
          ),
        ],
      );

  Widget _buildStatistics() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dropdown(
            label: 'Como aparece no histórico',
            value: _rules.historyMode,
            values: ChampionshipHistoryMode.values,
            text: _historyLabel,
            onChanged: (value) =>
                setState(() => _rules = _rules.copyWith(historyMode: value)),
          ),
          const SizedBox(height: 12),
          _dropdown(
            label: 'Resultado nas estatísticas',
            value: _rules.resultMode,
            values: ChampionshipResultMode.values,
            text: _resultLabel,
            onChanged: (value) =>
                setState(() => _rules = _rules.copyWith(resultMode: value)),
          ),
          if (_rules.resultMode == ChampionshipResultMode.winForAll)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Cada participante ganha 1 vitória nas estatísticas.',
              ),
            ),
          if (_rules.resultMode == ChampionshipResultMode.placement) ...[
            const SizedBox(height: 12),
            for (var index = 0;
                index < _rules.placementResults.length;
                index++) ...[
              _dropdown(
                label: '${index + 1}ª posição',
                value: _rules.placementResults[index],
                values: PlacementResult.values,
                text: placementResultLabel,
                onChanged: (value) => _setPlacement(index, value),
              ),
              const SizedBox(height: 8),
            ],
            TextFormField(
              key: ValueKey(
                'min-games-${_rules.minGamesForPlacementResult}',
              ),
              initialValue: '${_rules.minGamesForPlacementResult}',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Mínimo de jogos para receber o resultado',
                helperText: 'Quem jogou menos que isso conta só presença.',
              ),
              onChanged: (text) => setState(() => _rules = _rules.copyWith(
                    minGamesForPlacementResult: int.tryParse(text) ?? 0,
                  )),
            ),
          ],
          const SizedBox(height: 12),
          _dropdown(
            label: 'Votação de MVP',
            value: _rules.mvpMode,
            values: ChampionshipMvpMode.values,
            text: _mvpLabel,
            onChanged: (value) =>
                setState(() => _rules = _rules.copyWith(mvpMode: value)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('MVP conta nas estatísticas gerais'),
            value: _rules.mvpCountsInGeneralStats,
            onChanged: (value) => setState(
                () => _rules = _rules.copyWith(mvpCountsInGeneralStats: value)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Gols contam nas estatísticas gerais'),
            value: _rules.goalsCountInGeneralStats,
            onChanged: (value) => setState(() =>
                _rules = _rules.copyWith(goalsCountInGeneralStats: value)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Incluir no sorteio de times futuro'),
            value: _rules.includeInTeamDraw,
            onChanged: (value) => setState(
                () => _rules = _rules.copyWith(includeInTeamDraw: value)),
          ),
          const Divider(height: 28),
          _dropdown(
            label: 'Classificação',
            value: _rules.standings.mode,
            values: ChampionshipStandingMode.values,
            text: (value) => value == ChampionshipStandingMode.totalPoints
                ? 'Pontos totais'
                : 'Pontos por jogo',
            onChanged: (value) => _setStandings(mode: value),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _number(
                  label: 'Pontos por vitória',
                  value: _rules.standings.winPoints,
                  onChanged: (value) => _setStandings(winPoints: value),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _number(
                  label: 'Pontos por empate',
                  value: _rules.standings.drawPoints,
                  onChanged: (value) => _setStandings(drawPoints: value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Ordem dos desempates',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          for (var index = 0;
              index < _rules.standings.tiebreakers.length;
              index++)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 14,
                child: Text('${index + 1}'),
              ),
              title:
                  Text(_tiebreakerLabel(_rules.standings.tiebreakers[index])),
              subtitle: index == 0 ? const Text('Sempre o 1º critério') : null,
              trailing: index == 0
                  ? const Icon(Icons.lock_outline_rounded)
                  : Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Subir',
                          onPressed: index <= 1
                              ? null
                              : () => _moveTiebreaker(index, -1),
                          icon: const Icon(Icons.arrow_upward_rounded),
                        ),
                        IconButton(
                          tooltip: 'Descer',
                          onPressed:
                              index == _rules.standings.tiebreakers.length - 1
                                  ? null
                                  : () => _moveTiebreaker(index, 1),
                          icon: const Icon(Icons.arrow_downward_rounded),
                        ),
                      ],
                    ),
            ),
        ],
      );

  Widget _buildReview(bool mutating) {
    final liveErrors = _input.validate();
    final errors = _errors.isEmpty ? liveErrors : _errors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_name.text.trim().isEmpty ? 'Campeonato sem nome' : _name.text,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('${DateFormat('dd/MM/yyyy HH:mm').format(_playedAt)} · '
            '${_place.text.trim().isEmpty ? 'Local não informado' : _place.text}'),
        const SizedBox(height: 16),
        Text(championshipRulesSummary(_rules)),
        const SizedBox(height: 10),
        Text('${championshipFormatLabel(_rules.format)} · '
            'termina em "Encerrar campeonato"'),
        if (errors.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final error in errors)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $error',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
        if (mutating) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }

  Widget _number({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) =>
      TextFormField(
        key: ValueKey('$label-$value'),
        initialValue: '$value',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
        onChanged: (text) => onChanged(int.tryParse(text) ?? -1),
      );

  Widget _optionalNumber({
    required String label,
    required int? value,
    required ValueChanged<int?> onChanged,
  }) =>
      TextFormField(
        key: ValueKey('$label-$value'),
        initialValue: value?.toString() ?? '',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, hintText: 'Sem limite'),
        onChanged: (text) =>
            onChanged(text.trim().isEmpty ? null : int.tryParse(text) ?? -1),
      );

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> values,
    required String Function(T) text,
    required ValueChanged<T> onChanged,
  }) =>
      DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        isExpanded: true,
        items: [
          for (final item in values)
            DropdownMenuItem(value: item, child: Text(text(item))),
        ],
        onChanged: (item) {
          if (item != null) onChanged(item);
        },
      );

  void _setWinnerStays({
    int? limit,
    WinnerStaysTieRule? tieRule,
    WinnerStaysLimitRule? limitRule,
  }) {
    final current = _rules.winnerStays!;
    setState(() => _rules = _rules.copyWith(
          winnerStays: WinnerStaysRules(
            consecutiveWinsLimit: limit ?? current.consecutiveWinsLimit,
            tieRule: tieRule ?? current.tieRule,
            limitRule: limitRule ?? current.limitRule,
          ),
        ));
  }

  void _setGameEndTime(int? value) {
    setState(() => _rules = _rules.copyWith(
          gameEnd: ChampionshipGameEndRules(
            timeLimitMinutes: value,
            goalLimit: _rules.gameEnd.goalLimit,
          ),
        ));
  }

  void _setGameEndGoals(int? value) {
    setState(() => _rules = _rules.copyWith(
          gameEnd: ChampionshipGameEndRules(
            timeLimitMinutes: _rules.gameEnd.timeLimitMinutes,
            goalLimit: value,
          ),
        ));
  }

  void _setPlacement(int index, PlacementResult value) {
    final results = [..._rules.placementResults];
    results[index] = value;
    setState(() => _rules = _rules.copyWith(placementResults: results));
  }

  void _setStandings({
    ChampionshipStandingMode? mode,
    int? winPoints,
    int? drawPoints,
    List<ChampionshipTiebreakerCriteria>? tiebreakers,
  }) {
    final current = _rules.standings;
    setState(() => _rules = _rules.copyWith(
          standings: ChampionshipStandingsRules(
            mode: mode ?? current.mode,
            winPoints: winPoints ?? current.winPoints,
            drawPoints: drawPoints ?? current.drawPoints,
            tiebreakers: tiebreakers ?? current.tiebreakers,
          ),
        ));
  }

  void _moveTiebreaker(int index, int offset) {
    // Pontos fica travado na 1ª posição (contrato v6).
    if (index == 0 || index + offset < 1) return;
    final items = [..._rules.standings.tiebreakers];
    final item = items.removeAt(index);
    items.insert(index + offset, item);
    _setStandings(tiebreakers: items);
  }
}

String _historyLabel(ChampionshipHistoryMode value) => switch (value) {
      ChampionshipHistoryMode.consolidated => 'Conta como 1 partida',
      ChampionshipHistoryMode.separateGames => 'Jogos separados',
      ChampionshipHistoryMode.championshipOnly => 'Só no campeonato',
    };

String _resultLabel(ChampionshipResultMode value) => switch (value) {
      ChampionshipResultMode.perGame => 'Resultado por jogo',
      ChampionshipResultMode.placement => 'Resultado por colocação',
      ChampionshipResultMode.winForAll => 'Vitória para todos',
      ChampionshipResultMode.presenceOnly => 'Somente presença',
    };

String _mvpLabel(ChampionshipMvpMode value) => switch (value) {
      ChampionshipMvpMode.perGame => 'Um MVP por jogo',
      ChampionshipMvpMode.perChampionship => 'Um MVP do campeonato',
      ChampionshipMvpMode.none => 'Sem MVP',
    };

String _tieRuleLabel(WinnerStaysTieRule value) => switch (value) {
      WinnerStaysTieRule.bothLeave => 'Saem os dois',
      WinnerStaysTieRule.longestOnFieldLeaves => 'Sai quem está há mais tempo',
      WinnerStaysTieRule.penaltyShootout => 'Decisão por pênaltis',
    };

String _limitRuleLabel(WinnerStaysLimitRule value) => switch (value) {
      WinnerStaysLimitRule.winnerLeaves => 'Sai só o vencedor',
      WinnerStaysLimitRule.bothLeave => 'Saem os dois',
    };

String _tiebreakerLabel(ChampionshipTiebreakerCriteria value) =>
    switch (value) {
      ChampionshipTiebreakerCriteria.points => 'Pontos',
      ChampionshipTiebreakerCriteria.goalDifference => 'Saldo de gols',
      ChampionshipTiebreakerCriteria.goalsFor => 'Gols pró',
      ChampionshipTiebreakerCriteria.headToHead => 'Confronto direto',
      ChampionshipTiebreakerCriteria.externalDecision =>
        'Decisão externa (sorteio/pênaltis)',
    };

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/app_page_header.dart';
import '../../../../shared/presentation/widgets/no_active_group_view.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../data/datasources/team_builder_datasource.dart';
import '../../domain/entities/team_builder_models.dart';
import '../../domain/team_builder_format.dart';
import '../widgets/team_builder_pitch.dart';
import '../widgets/team_builder_sheets.dart';

final _teamBuilderDsProvider = Provider<TeamBuilderDataSource>(
  (ref) => TeamBuilderDataSource(ref.watch(dioProvider)),
);

final _groupNameProvider =
    FutureProvider.family<String, String>((ref, groupId) async {
  final res = await ref.watch(dioProvider).get(ApiConstants.groupById(groupId));
  final raw = res.data;
  final body =
      raw is Map<String, dynamic> && raw['data'] is Map<String, dynamic>
          ? raw['data'] as Map<String, dynamic>
          : (raw is Map<String, dynamic> ? raw : const <String, dynamic>{});
  return (body['name'] ?? '') as String;
});

Color _muted(BuildContext context) =>
    context.isDarkTheme ? AppColors.darkTextMuted : AppColors.lightTextMuted;

/// Monte seu Time: escolha de 2 a 5 jogadores e como se saem jogando juntos
/// (só partidas em que todos estavam no mesmo time). Só para admin da patota.
class TeamBuilderPage extends ConsumerStatefulWidget {
  const TeamBuilderPage({super.key});

  @override
  ConsumerState<TeamBuilderPage> createState() => _TeamBuilderPageState();
}

class _TeamBuilderPageState extends ConsumerState<TeamBuilderPage> {
  TeamBuilderPeriod _period = TeamBuilderPeriod.season(DateTime.now().year);
  bool _champ = true;
  TeamBuilderPlayers? _list;
  final List<TeamBuilderPlayer> _selected = [];
  TeamBuilderStats? _stats;
  bool _loading = false;
  String? _error;
  Timer? _debounce;
  int _request = 0;
  String? _loadedFor;

  TeamBuilderFilter get _filter =>
      _period.toFilter(includeChampionship: _champ);

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadPlayers(String groupId) async {
    try {
      final data =
          await ref.read(_teamBuilderDsProvider).fetchPlayers(groupId, _filter);
      if (!mounted) return;
      setState(() => _list = data);
      // Primeira carga: se a temporada atual não tem jogos, abre na mais recente.
      final season = _period.season;
      if (season != null &&
          data.seasons.isNotEmpty &&
          !data.seasons.contains(season)) {
        _setPeriod(groupId, TeamBuilderPeriod.season(data.seasons.first));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Erro ao carregar jogadores.');
    }
  }

  void _setPeriod(String groupId, TeamBuilderPeriod period) {
    setState(() => _period = period);
    _loadPlayers(groupId);
    _scheduleStats(groupId);
  }

  void _toggleChamp(String groupId) {
    setState(() => _champ = !_champ);
    _loadPlayers(groupId);
    _scheduleStats(groupId);
  }

  void _toggle(String groupId, TeamBuilderPlayer p) {
    setState(() {
      if (_selected.any((s) => s.id == p.id)) {
        _selected.removeWhere((s) => s.id == p.id);
      } else if (canAddPlayer(_selected, p)) {
        _selected.add(p);
      }
    });
    _scheduleStats(groupId);
  }

  void _scheduleStats(String groupId) {
    _debounce?.cancel();
    final id = ++_request;
    if (_selected.length < 2) {
      setState(() {
        _stats = null;
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final result = await ref
            .read(_teamBuilderDsProvider)
            .fetchStats(groupId, _selected.map((p) => p.id).toList(), _filter);
        if (!mounted || id != _request) return;
        setState(() {
          _stats = result;
          _error = null;
          _loading = false;
        });
      } on DioException catch (e) {
        if (!mounted || id != _request) return;
        final data = e.response?.data;
        setState(() {
          _error = data is Map && data['error'] is String
              ? data['error'] as String
              : 'Erro ao buscar estatísticas.';
          _loading = false;
        });
      } catch (_) {
        if (!mounted || id != _request) return;
        setState(() {
          _error = 'Erro inesperado. Tente novamente.';
          _loading = false;
        });
      }
    });
  }

  Future<void> _pickSince(String groupId) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _period.since ?? DateTime(now.year, now.month, 1),
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'Jogos desde',
    );
    if (picked != null) _setPeriod(groupId, TeamBuilderPeriod.since(picked));
  }

  void _openPicker(String groupId) {
    final list = _list;
    if (list == null) return;
    showTeamBuilderPicker(
      context,
      players: list.players,
      selected: () => _selected,
      onToggle: (p) => _toggle(groupId, p),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    final groupId = account?.activeGroupId ?? activePlayer?.groupId ?? '';
    final isAdmin =
        groupId.isNotEmpty && (account?.isGroupAdmin(groupId) ?? false);

    const header = AppPageHeader(
      title: 'Monte seu Time',
      subtitle: 'Escolha de 2 a 5 jogadores',
      icon: Icons.groups_2_outlined,
    );

    if (groupId.isEmpty || !isAdmin) {
      return Scaffold(
        body: Column(children: [
          header,
          Expanded(
            child: NoActiveGroupView(
              message: groupId.isEmpty
                  ? 'Selecione uma patota para montar seu time.'
                  : 'Monte seu Time é só para administradores da patota.',
            ),
          ),
        ]),
      );
    }

    if (_loadedFor != groupId) {
      _loadedFor = groupId;
      _list = null;
      _selected.clear();
      _stats = null;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _loadPlayers(groupId));
    }

    final groupName = ref.watch(_groupNameProvider(groupId)).valueOrNull ?? '';
    final stats = _stats;
    final ok = stats != null &&
        !stats.neverPlayedTogether &&
        _selected.length >= 2 &&
        !_loading;
    final seasons = _list?.seasons.isNotEmpty == true
        ? _list!.seasons
        : [DateTime.now().year];
    final muted = _muted(context);

    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppPageHeader(
                  title: 'Monte seu Time',
                  subtitle: groupName.isEmpty
                      ? 'Escolha de 2 a 5 jogadores'
                      : '$groupName · escolha de 2 a 5 jogadores',
                  icon: Icons.groups_2_outlined,
                ),
                const SizedBox(height: 12),
                // Altura fixa: dentro do scroll, a fila de chips não pode encolher.
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _Chip(
                        label: 'Temporada ${_period.season ?? seasons.first}',
                        on: _period.season != null,
                        // Já marcado e com mais de uma temporada: toque de novo escolhe outra.
                        onTap: _period.season != null && seasons.length > 1
                            ? () => _pickSeason(groupId, seasons)
                            : () => _setPeriod(
                                groupId,
                                TeamBuilderPeriod.season(
                                    _period.season ?? seasons.first)),
                      ),
                      _Chip(
                        label: _period.since != null
                            ? 'Desde ${ddmm(_period.since!)}'
                            : 'Desde uma data',
                        on: _period.since != null,
                        onTap: () => _pickSince(groupId),
                      ),
                      _Chip(
                        label: 'Últimos 10 jogos',
                        on: _period.lastMatches == 10,
                        onTap: () => _setPeriod(
                            groupId, const TeamBuilderPeriod.last(10)),
                      ),
                      _Chip(
                        label: '${_champ ? '✓ ' : ''}Jogos de campeonato',
                        on: _champ,
                        onTap: () => _toggleChamp(groupId),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Stack(children: [
                        TeamBuilderPitch(
                          players: _selected,
                          onEmptyTap: () => _openPicker(groupId),
                          onPlayerTap: (_) => _openPicker(groupId),
                          sub: (p) {
                            final b = ok ? stats.breakdownOf(p.id) : null;
                            return b == null ? '' : '${b.overallPointsPct}%';
                          },
                        ),
                        if (_loading)
                          const Positioned.fill(
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.onDark)),
                          ),
                      ]),
                      if (_selected.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final p in _selected)
                              _SelectedTag(
                                  player: p,
                                  onRemove: () => _toggle(groupId, p))
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      _PickButton(
                          count: _selected.length,
                          onTap: _list == null
                              ? null
                              : () => _openPicker(groupId)),
                      const SizedBox(height: 14),
                      if (_error != null)
                        _Card(
                            child: Text(_error!,
                                style: TextStyle(
                                    color: context.appDanger, fontSize: 13)))
                      else if (_selected.length < 2)
                        _Card(
                            child: _Empty(
                                'Escolha pelo menos 2 jogadores para ver como eles jogam juntos.',
                                muted))
                      else if (stats == null)
                        const SizedBox(
                            height: 120,
                            child: Center(child: CircularProgressIndicator()))
                      else if (stats.neverPlayedTogether)
                        _Card(
                          child: _Empty(
                            'Nunca jogaram juntos no mesmo time nesse período.'
                            '${stats.oppositeTeamsMatches > 0 ? '\nEstiveram em ${stats.oppositeTeamsMatches} ${stats.oppositeTeamsMatches == 1 ? 'jogo' : 'jogos'}, mas em times opostos.' : ''}',
                            muted,
                          ),
                        )
                      else
                        _StatsCards(stats: stats),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    disabledBackgroundColor: context.appSurfaceElevated,
                    disabledForegroundColor: muted,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  onPressed: ok
                      ? () => showTeamBuilderShare(
                            context,
                            stats: stats,
                            players: List.of(_selected),
                            groupName: groupName,
                            period: _period.label,
                          )
                      : null,
                  child: const Text('Compartilhar com os dados'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSeason(String groupId, List<int> seasons) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: context.appSurface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in seasons)
              ListTile(
                  title: Text('Temporada $s'),
                  onTap: () => Navigator.of(ctx).pop(s)),
          ],
        ),
      ),
    );
    if (picked != null) _setPeriod(groupId, TeamBuilderPeriod.season(picked));
  }
}

// ── Peças ─────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: on ? AppColors.accent16 : context.appSurface,
        shape: StadiumBorder(
            side:
                BorderSide(color: on ? AppColors.accent42 : context.appBorder)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: on ? AppColors.accent : context.appTextSecondary)),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedTag extends StatelessWidget {
  const _SelectedTag({required this.player, required this.onRemove});

  final TeamBuilderPlayer player;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Tirar ${player.name}',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onRemove,
        child: Container(
          padding: const EdgeInsets.fromLTRB(5, 5, 10, 5),
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(
              radius: 11,
              backgroundColor: player.isGoalkeeper
                  ? AppColors.goalkeeperYellow
                  : context.appSurfaceElevated,
              child: Text(initialsOf(player.name),
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: player.isGoalkeeper
                          ? AppColors.slate950
                          : context.appTextPrimary)),
            ),
            const SizedBox(width: 6),
            Text(player.shortName,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary)),
            const SizedBox(width: 4),
            Text('×', style: TextStyle(fontSize: 13, color: _muted(context))),
          ]),
        ),
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  const _PickButton({required this.count, this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.accent42, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.add_rounded, size: 18, color: AppColors.accent),
            const SizedBox(width: 6),
            const Text('Escolher jogadores',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent)),
            const SizedBox(width: 8),
            Text('$count/$teamBuilderMaxPlayers',
                style: TextStyle(fontSize: 12, color: _muted(context))),
          ]),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.title, this.trailing});

  final Widget child;
  final String? title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: context.appSurface, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(children: [
              Expanded(
                child: Text(title!,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.appTextSecondary)),
              ),
              if (trailing != null)
                Text(trailing!,
                    style: TextStyle(fontSize: 11.5, color: _muted(context))),
            ]),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.5, color: color)),
      );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.valueWidget});
  final String label;
  final String value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary)),
          ),
          const SizedBox(width: 10),
          valueWidget ??
              Text(value,
                  style:
                      TextStyle(fontSize: 12, color: context.appTextSecondary)),
        ]),
      );
}

class _Rich extends StatelessWidget {
  const _Rich(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          for (final p in boldParts(text))
            TextSpan(
              text: p.text,
              style: p.bold
                  ? TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary)
                  : null,
            ),
        ]),
        style: TextStyle(
            fontSize: 13, height: 1.45, color: context.appTextSecondary),
      );
}

class _StatsCards extends StatelessWidget {
  const _StatsCards({required this.stats});
  final TeamBuilderStats stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final n = s.totalMatches;
    final up = context.appSuccess;
    final down = context.appDanger;
    final muted = _muted(context);

    Widget kv(String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: context.appSurfaceSubtle,
                borderRadius: BorderRadius.circular(12)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary)),
              Text(label, style: TextStyle(fontSize: 11, color: muted)),
            ]),
          ),
        );

    Widget record(OpponentRecord o) => Text.rich(
          TextSpan(children: [
            TextSpan(text: '${o.wins}V ', style: TextStyle(color: up)),
            TextSpan(text: '${o.draws}E '),
            TextSpan(text: '${o.losses}D', style: TextStyle(color: down)),
          ]),
          style: TextStyle(fontSize: 12, color: context.appTextSecondary),
        );

    final shownMatches = s.matches.take(8).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Card(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s.pointsPct}%',
                  style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: context.appTextPrimary)),
              const SizedBox(height: 4),
              Text(
                  'aproveitamento · $n ${n == 1 ? 'jogo junto' : 'jogos juntos'}',
                  style: TextStyle(fontSize: 12, color: muted)),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(verdictOf(s.pointsPct),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent)),
                Text('média deles: ${s.averageIndividualPointsPct}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: s.pointsPct >= s.averageIndividualPointsPct
                            ? up
                            : down)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 8,
              child: Row(children: [
                if (s.wins > 0)
                  Expanded(
                      flex: s.wins,
                      child: const ColoredBox(color: AppColors.accent)),
                if (s.draws > 0)
                  Expanded(
                      flex: s.draws,
                      child: const ColoredBox(color: AppColors.warning)),
                if (s.losses > 0)
                  Expanded(
                      flex: s.losses,
                      child:
                          const ColoredBox(color: AppColors.prototypeDanger)),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            kv('${s.wins}·${s.draws}·${s.losses}', 'V · E · D'),
            const SizedBox(width: 8),
            kv('${s.goalsScored}–${s.goalsConceded}', 'gols do time'),
            const SizedBox(width: 8),
            kv(oneDecimal(s.goalsPerMatch), 'gols por jogo'),
          ]),
        ]),
      ),
      _Card(
        title: 'Destaques',
        child: Column(children: [
          if (s.biggestWin != null)
            _Row('Maior vitória',
                '${s.biggestWin!.goalsFor}×${s.biggestWin!.goalsAgainst} em ${ddmm(s.biggestWin!.playedAt)}'),
          if (s.worstLoss != null)
            _Row('Pior derrota',
                '${s.worstLoss!.goalsFor}×${s.worstLoss!.goalsAgainst} em ${ddmm(s.worstLoss!.playedAt)}'),
          if (s.currentStreak != null)
            _Row('Momento', streakText(s.currentStreak!)),
          if (s.lastMatch != null)
            _Row('Último jogo juntos',
                '${resultWord(s.lastMatch!.result)} ${s.lastMatch!.goalsFor}×${s.lastMatch!.goalsAgainst} · ${ddmm(s.lastMatch!.playedAt)}'),
        ]),
      ),
      _Card(
        title: 'Cada um nesses jogos',
        trailing: 'G · A · MVP · geral → juntos',
        child: Column(children: [
          for (final p in s.playerBreakdown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(
                  child: Text('${p.isGoalkeeper ? '🧤 ' : ''}${p.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary)),
                ),
                Text('${p.goals} · ${p.assists} · ${p.mvps}',
                    style: TextStyle(
                        fontSize: 12, color: context.appTextSecondary)),
                SizedBox(
                  width: 92,
                  child: Text('${p.overallPointsPct}% → ${s.pointsPct}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color:
                              s.pointsPct >= p.overallPointsPct ? up : down)),
                ),
              ]),
            ),
          const SizedBox(height: 4),
          Text(
              'Geral é o aproveitamento de cada um em todos os jogos do período. Juntos é o aproveitamento com esse time.',
              style: TextStyle(fontSize: 11, color: muted)),
        ]),
      ),
      if (s.assistPairs.isNotEmpty)
        _Card(
          title: 'Passes entre eles',
          child: Column(children: [
            for (final a in s.assistPairs)
              _Row('${a.assisterName} → ${a.scorerName}',
                  '${a.count} ${a.count > 1 ? 'gols' : 'gol'}'),
          ]),
        ),
      if (s.nemesis != null || s.favoriteVictim != null)
        _Card(
          title: 'Contra quem',
          trailing: 'mín. 3 jogos',
          child: Column(children: [
            if (s.nemesis != null)
              _Row('Pedra no sapato: ${s.nemesis!.shortName}', '',
                  valueWidget: record(s.nemesis!)),
            if (s.favoriteVictim != null)
              _Row('Freguês: ${s.favoriteVictim!.shortName}', '',
                  valueWidget: record(s.favoriteVictim!)),
          ]),
        ),
      if (s.curiosities.isNotEmpty)
        _Card(
          title: 'Curiosidades',
          child: Column(children: [
            for (final c in s.curiosities)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 7, right: 10),
                        decoration: const BoxDecoration(
                            color: AppColors.accent, shape: BoxShape.circle),
                      ),
                      Expanded(child: _Rich(c)),
                    ]),
              ),
          ]),
        ),
      _Card(
        title: 'Jogos juntos',
        trailing: '$n',
        child: Column(children: [
          for (var i = 0; i < shownMatches.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(top: BorderSide(color: context.appBorder)),
              ),
              child: Row(children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: shownMatches[i].result > 0
                        ? AppColors.accent
                        : shownMatches[i].result == 0
                            ? AppColors.warning
                            : AppColors.prototypeDanger,
                  ),
                  child: Text(resultLetter(shownMatches[i].result),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: shownMatches[i].result < 0
                              ? AppColors.onDark
                              : AppColors.slate950)),
                ),
                const SizedBox(width: 10),
                Text(
                    '${shownMatches[i].goalsFor}×${shownMatches[i].goalsAgainst}',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: context.appTextPrimary)),
                if (shownMatches[i].isChampionship) ...[
                  const SizedBox(width: 8),
                  Text('campeonato',
                      style: TextStyle(fontSize: 11, color: muted)),
                ],
                const Spacer(),
                Text(ddmm(shownMatches[i].playedAt),
                    style: TextStyle(fontSize: 12.5, color: muted)),
              ]),
            ),
          if (n > shownMatches.length)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('e mais ${n - shownMatches.length}',
                  style: TextStyle(fontSize: 12, color: muted)),
            ),
        ]),
      ),
    ]);
  }
}

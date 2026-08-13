import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/date_utils.dart';
import '../../data/datasources/match_remote_datasource.dart';
import '../../domain/entities/match_models.dart';

// ── Datasource provider ───────────────────────────────────────────────────────

final matchDsProvider = Provider<MatchRemoteDataSource>(
  (ref) => MatchRemoteDataSource(ref.watch(dioProvider)),
);

// ── Notifier ──────────────────────────────────────────────────────────────────

class MatchNotifier extends StateNotifier<MatchState> {
  final MatchRemoteDataSource _ds;
  final String groupId;
  final bool isAdmin;
  Timer? _refreshTimer;

  MatchNotifier(this._ds, this.groupId, this.isAdmin)
      : super(const MatchState());

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ── Helpers internos ──────────────────────────────────────────────────────

  String _id(dynamic v) => (v ?? '').toString();

  List<MatchPlayerInfo> _parsePlayers(dynamic v) => (v as List? ?? [])
      .map((e) => MatchPlayerInfo.fromJson(e as Map<String, dynamic>))
      .toList();

  List<MatchGoal> _parseGoals(dynamic v) => (v as List? ?? [])
      .map((e) => MatchGoal.fromJson(e as Map<String, dynamic>))
      .toList();

  TeamColorInfo? _parseColor(dynamic v) =>
      v is Map<String, dynamic> ? TeamColorInfo.fromJson(v) : null;

  /// Aplica o payload do header ao state.
  void _applyHeader(Map<String, dynamic>? d) {
    if (d == null) return;
    final rawStep = d['stepKey'] ?? d['StepKey'];
    final rawStatus = d['status'] ?? d['Status'];
    final step = rawStep != null
        ? MatchStep.fromKey(rawStep.toString())
        : MatchStep.fromStatus((rawStatus as num?)?.toInt() ?? 0);

    final playedAt =
        parseApiDateOrNull((d['playedAt'] ?? d['PlayedAt'])?.toString());
    final actualStartTime = parseApiDateOrNull(
        (d['actualStartTime'] ?? d['ActualStartTime'])?.toString());

    state = state.copyWith(
      matchId: _id(d['matchId'] ?? d['MatchId'] ?? d['id'] ?? d['Id']).isEmpty
          ? state.matchId
          : _id(d['matchId'] ?? d['MatchId'] ?? d['id'] ?? d['Id']),
      step: step,
      placeName: d['placeName'] as String? ??
          d['PlaceName'] as String? ??
          state.placeName,
      playedAt: playedAt ?? state.playedAt,
      canRewind: d['canRewind'] as bool? ?? d['CanRewind'] as bool? ?? false,
      teamAGoals:
          (d['teamAGoals'] ?? d['TeamAGoals']) as int? ?? state.teamAGoals,
      teamBGoals:
          (d['teamBGoals'] ?? d['TeamBGoals']) as int? ?? state.teamBGoals,
      linkedPollId: (d['linkedPollId'] ?? d['LinkedPollId'])?.toString(),
      actualStartTime: actualStartTime ?? state.actualStartTime,
    );
  }

  /// Aplica o payload de aceitação ao state.
  void _applyAcceptation(Map<String, dynamic>? d) {
    if (d == null) return;
    state = state.copyWith(
      acceptedPlayers:
          _parsePlayers(d['acceptedPlayers'] ?? d['AcceptedPlayers']),
      rejectedPlayers:
          _parsePlayers(d['rejectedPlayers'] ?? d['RejectedPlayers']),
      pendingPlayers: _parsePlayers(d['pendingPlayers'] ?? d['PendingPlayers']),
      maxPlayers:
          (d['maxPlayers'] ?? d['MaxPlayers']) as int? ?? state.maxPlayers,
      acceptedOverLimit: d['acceptedOverLimit'] as bool? ??
          d['AcceptedOverLimit'] as bool? ??
          false,
      canAdvanceToMatchmaking: d['canAdvanceToMatchmaking'] as bool? ??
          d['CanAdvanceToMatchmaking'] as bool? ??
          false,
    );
  }

  /// Aplica o payload de matchmaking ao state.
  void _applyMatchmaking(Map<String, dynamic>? d) {
    if (d == null) return;
    state = state.copyWith(
      teamAColor: _parseColor(d['teamAColor'] ?? d['TeamAColor']),
      teamBColor: _parseColor(d['teamBColor'] ?? d['TeamBColor']),
      teamAPlayers: _parsePlayers(d['teamAPlayers'] ?? d['TeamAPlayers']),
      teamBPlayers: _parsePlayers(d['teamBPlayers'] ?? d['TeamBPlayers']),
      unassignedPlayers:
          _parsePlayers(d['unassignedPlayers'] ?? d['UnassignedPlayers']),
      participants: _parsePlayers(d['participants'] ?? d['Participants']),
      colorsLocked:
          d['colorsLocked'] as bool? ?? d['ColorsLocked'] as bool? ?? false,
      canStartMatch:
          d['canStartMatch'] as bool? ?? d['CanStartMatch'] as bool? ?? false,
    );
  }

  /// Aplica o payload de pós-jogo ao state.
  void _applyPostgame(Map<String, dynamic>? d) {
    if (d == null) return;
    state = state.copyWith(
      teamAGoals: (d['teamAGoals'] ?? d['TeamAGoals']) as int?,
      teamBGoals: (d['teamBGoals'] ?? d['TeamBGoals']) as int?,
      goals: _parseGoals(d['goals'] ?? d['Goals']),
      computedMvps: ((d['computedMvps'] ?? d['ComputedMvps']) as List? ?? [])
          .map((e) => MvpInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      votes: ((d['votes'] ?? d['Votes']) as List? ?? [])
          .map((e) => VoteInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      voteCounts: ((d['voteCounts'] ?? d['VoteCounts']) as List? ?? [])
          .map((e) => VoteCount.fromJson(e as Map<String, dynamic>))
          .toList(),
      allVoted: d['allVoted'] as bool? ?? d['AllVoted'] as bool? ?? false,
      eligibleVoters: _parsePlayers(d['eligibleVoters'] ?? d['EligibleVoters']),
      participants: _parsePlayers(d['participants'] ?? d['Participants']),
      canVote: d['canVote'] as bool? ?? d['CanVote'] as bool?,
      hasVoted: d['hasVoted'] as bool? ?? d['HasVoted'] as bool?,
      myVotedForMatchPlayerId:
          (d['myVotedForMatchPlayerId'] ?? d['MyVotedForMatchPlayerId'])
              ?.toString(),
    );
  }

  // ── Carregamento por step ─────────────────────────────────────────────────

  Future<void> _loadStepPayload(String matchId, MatchStep step) async {
    final header =
        await _ds.fetchHeader(groupId, matchId).catchError((_) => null);
    if (!mounted) return;
    _applyHeader(header);

    // O /current stub nem sempre tem `status`, então `step` pode estar errado.
    // Após _applyHeader, state.step reflete o stepKey real do backend.
    // Usamos state.step para garantir que carregamos o payload correto.
    final effectiveStep = state.step;

    switch (effectiveStep) {
      case MatchStep.accept:
        final d = await _ds
            .fetchAcceptation(groupId, matchId)
            .catchError((_) => null);
        if (!mounted) return;
        _applyAcceptation(d);
      case MatchStep.teams:
        final d = await _ds
            .fetchMatchmaking(groupId, matchId)
            .catchError((_) => null);
        if (!mounted) return;
        _applyMatchmaking(d);
      case MatchStep.playing:
        final d = await _ds
            .fetchMatchmaking(groupId, matchId)
            .catchError((_) => null);
        if (!mounted) return;
        _applyMatchmaking(d);
        final details = await _ds
            .fetchMatchDetails(groupId, matchId)
            .catchError((_) => null);
        if (!mounted) return;
        if (details != null) {
          state = state.copyWith(
            teamAGoals:
                (details['teamAGoals'] ?? details['TeamAGoals']) as int?,
            teamBGoals:
                (details['teamBGoals'] ?? details['TeamBGoals']) as int?,
            goals: _parseGoals(details['goals'] ?? details['Goals']),
          );
        }
      case MatchStep.post:
      case MatchStep.done:
        // O placar final também precisa das cores e dos nomes definidos na
        // escalação. O payload de pós-jogo não os inclui.
        final matchmaking = await _ds
            .fetchMatchmaking(groupId, matchId)
            .catchError((_) => null);
        if (!mounted) return;
        _applyMatchmaking(matchmaking);
        final d =
            await _ds.fetchPostgame(groupId, matchId).catchError((_) => null);
        if (!mounted) return;
        _applyPostgame(d);
      default:
        break;
    }
  }

  // ── API pública ───────────────────────────────────────────────────────────

  /// Carrega estado inicial: cores, config e partida atual.
  Future<void> loadInitial() async {
    if (groupId.isEmpty) return;
    state = state.copyWith(loading: true, error: null);
    try {
      // Carrega cores, configurações e lista de partidas em paralelo.
      //
      // `/current` foi removido daqui: ele devolve o MatchDetailsDto inteiro
      // (escalação, gols, times, aceitação, pós-jogo) só para extrairmos id,
      // stepKey e placeName — que o `upcoming` já traz num payload pequeno.
      // Era a chamada mais lenta da abertura do app. É o mesmo caminho que o
      // site usa: upcoming → escolhe a partida → carrega só a etapa atual.
      final results = await Future.wait([
        _ds.fetchTeamColors(groupId).catchError((_) => <TeamColorInfo>[]),
        _ds.fetchGroupSettings(groupId).catchError((_) => null),
        _ds.fetchUpcomingMatches(groupId).catchError((_) => <MatchHeaderDto>[]),
      ]);
      if (!mounted) return;

      final colors = results[0] as List<TeamColorInfo>;
      final settings = results[1] as MatchGroupSettings?;
      final upcoming = results[2] as List<MatchHeaderDto>;

      state = state.copyWith(
        availableColors: colors,
        groupSettings: settings,
        upcomingHeaders: upcoming,
        loading: false,
      );

      // Pré-preenche local a partir das configurações do grupo
      if (settings != null) {
        state = state.copyWith(
          placeName: state.placeName ?? settings.defaultPlaceName,
        );
      }

      // Sem partida em aberto → estado create
      if (upcoming.isEmpty) {
        state = state.copyWith(
          matchId: null,
          step: MatchStep.create,
          selectedMatchIdx: 0,
        );
        return;
      }

      // Mantém a partida já selecionada quando ela continua na lista; senão
      // cai na primeira. Mesma prioridade que o site aplica.
      final previousId = state.matchId;
      final keptIdx = previousId == null
          ? -1
          : upcoming.indexWhere((h) => h.matchId == previousId);
      final idx = keptIdx >= 0
          ? keptIdx
          : state.selectedMatchIdx.clamp(0, upcoming.length - 1);
      final header = upcoming[idx];

      if (header.matchId.isEmpty) {
        state = state.copyWith(matchId: null, step: MatchStep.create);
        return;
      }

      state = state.copyWith(
        matchId: header.matchId,
        step: header.step,
        selectedMatchIdx: idx,
        placeName: header.placeName,
        canRewind: header.canRewind,
        teamAGoals: header.teamAGoals,
        teamBGoals: header.teamBGoals,
      );

      await _loadStepPayload(header.matchId, header.step);
      if (!mounted) return;

      // Auto-refresh para não-admin
      if (!isAdmin) {
        _refreshTimer?.cancel();
        _refreshTimer = Timer.periodic(
          const Duration(seconds: 15),
          (_) => refresh(),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 404) {
        state = state.copyWith(
            loading: false, matchId: null, step: MatchStep.create);
      } else {
        state = state.copyWith(
            loading: false,
            error: extractDioError(e, 'Falha ao carregar partida.'));
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
          loading: false,
          error: extractDioError(e, 'Falha ao carregar dados.'));
    }
  }

  /// Carrega uma partida específica por ID (usado ao navegar do dashboard).
  Future<void> loadMatchById(String matchId) async {
    if (groupId.isEmpty || matchId.isEmpty) {
      await loadInitial();
      return;
    }
    state = state.copyWith(loading: true, error: null);
    try {
      final results = await Future.wait([
        _ds.fetchTeamColors(groupId).catchError((_) => <TeamColorInfo>[]),
        _ds.fetchGroupSettings(groupId).catchError((_) => null),
        _ds.fetchUpcomingMatches(groupId).catchError((_) => <MatchHeaderDto>[]),
      ]);

      final upcoming = results[2] as List<MatchHeaderDto>;
      final selIdx = upcoming.indexWhere((h) => h.matchId == matchId);
      state = state.copyWith(
        availableColors: results[0] as List<TeamColorInfo>,
        groupSettings: results[1] as MatchGroupSettings?,
        upcomingHeaders: upcoming,
        matchId: matchId,
        selectedMatchIdx: selIdx >= 0 ? selIdx : 0,
        loading: false,
      );

      if ((results[1] as MatchGroupSettings?) != null) {
        state = state.copyWith(
            placeName: state.placeName ??
                (results[1] as MatchGroupSettings).defaultPlaceName);
      }

      await _loadStepPayload(matchId, MatchStep.accept);

      if (!isAdmin) {
        _refreshTimer?.cancel();
        _refreshTimer = Timer.periodic(
          const Duration(seconds: 15),
          (_) => refresh(),
        );
      }
    } on DioException catch (e) {
      state = state.copyWith(
          loading: false,
          error: extractDioError(e, 'Falha ao carregar partida.'));
    } catch (e) {
      state = state.copyWith(
          loading: false,
          error: extractDioError(e, 'Falha ao carregar dados.'));
    }
  }

  /// Recarrega apenas o step atual.
  Future<void> refresh() async {
    final matchId = state.matchId;
    if (matchId == null || matchId.isEmpty) return;
    await _loadStepPayload(matchId, state.step);
  }

  // ── Step 1 – Criar ────────────────────────────────────────────────────────

  Future<bool> createMatch(String placeName, DateTime playedAt) async {
    state = state.copyWith(mutating: true, error: null);
    try {
      await _ds.createMatch(groupId, placeName, playedAt);
      await loadInitial();
      return true;
    } catch (e) {
      state =
          state.copyWith(error: extractDioError(e, 'Falha ao criar partida.'));
      return false;
    } finally {
      // `loadInitial()` mexe em `loading`, nunca em `mutating`. Sem este
      // `finally`, o caminho de sucesso saía com `mutating: true` preso e o
      // botão girava para sempre.
      state = state.copyWith(mutating: false);
    }
  }

  Future<bool> updateMatch(String placeName, DateTime playedAt) async {
    final matchId = state.matchId;
    if (matchId == null || matchId.isEmpty) return false;
    state = state.copyWith(mutating: true, error: null);
    try {
      await _ds.updateMatch(groupId, matchId, placeName, playedAt);
      state = state.copyWith(placeName: placeName, playedAt: playedAt);
      await _loadStepPayload(matchId, state.step);
      return true;
    } catch (e) {
      state = state.copyWith(
        error: extractDioError(e, 'Falha ao atualizar partida.'),
      );
      return false;
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  // ── Step 2 – Aceitação ────────────────────────────────────────────────────

  /// Marca/desmarca um jogador como "em voo" sem tocar nos demais.
  void _setPlayerPending(String playerId, bool pending) {
    final next = Set<String>.from(state.pendingPlayerIds);
    if (pending) {
      next.add(playerId);
    } else {
      next.remove(playerId);
    }
    state = state.copyWith(pendingPlayerIds: next);
  }

  /// Aceita/recusa um convite. Trava só a linha daquele jogador — o admin
  /// costuma percorrer a lista aceitando vários seguidos, e travar a tela
  /// inteira a cada toque tornava isso um de cada vez.
  Future<void> _respondInvite(
    String playerId, {
    required Future<void> Function() call,
    required String errorMessage,
  }) async {
    if (state.matchId == null) return;
    // Toque repetido na mesma linha não dispara um segundo request.
    if (state.pendingPlayerIds.contains(playerId)) return;

    _setPlayerPending(playerId, true);
    try {
      await call();
      await refresh();
    } catch (e) {
      state = state.copyWith(error: extractDioError(e, errorMessage));
    } finally {
      // `refresh()` reconstrói o estado, então o jogador precisa sair do
      // conjunto depois dela — senão a linha ficaria travada para sempre.
      _setPlayerPending(playerId, false);
    }
  }

  Future<void> acceptInvite(String playerId) => _respondInvite(
        playerId,
        call: () => _ds.acceptInvite(groupId, state.matchId!, playerId),
        errorMessage: 'Falha ao aceitar convite.',
      );

  Future<void> rejectInvite(String playerId) => _respondInvite(
        playerId,
        call: () => _ds.rejectInvite(groupId, state.matchId!, playerId),
        errorMessage: 'Falha ao recusar convite.',
      );

  Future<void> goToMatchmaking() async {
    final matchId = state.matchId;
    if (matchId == null) return;
    state = state.copyWith(mutating: true);
    try {
      await _ds.goToMatchmaking(groupId, matchId);
      await _loadStepPayload(matchId, MatchStep.teams);
    } catch (e) {
      state = state.copyWith(
          error: extractDioError(e, 'Falha ao avançar para matchmaking.'));
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<void> addGuest(String name, bool isGoalkeeper, int? starRating) async {
    final matchId = state.matchId;
    if (matchId == null) return;
    state = state.copyWith(mutating: true);
    try {
      await _ds.addGuest(groupId, matchId, name, isGoalkeeper, starRating);
      final d = await _ds.fetchAcceptation(groupId, matchId);
      _applyAcceptation(d);
    } catch (e) {
      state = state.copyWith(
          error: extractDioError(e, 'Falha ao adicionar convidado.'));
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  // ── Step 3 – MatchMaking ──────────────────────────────────────────────────

  Future<void> generateTeams({
    required int strategyType,
    required int playersPerTeam,
    required bool includeGoalkeepers,
  }) async {
    // União de todas as fontes de jogadores aceitos, deduplicada por matchPlayerId.
    // participants = todos os aceitos; unassigned/teamA/teamB cobrem cenários
    // onde participants está vazio ou incompleto.
    final allPlayers = state.formationPlayers;
    state = state.copyWith(
        mutating: true, teamGenOptions: [], selectedTeamGenIdx: 0);
    try {
      final options = await _ds.generateTeams(
        players: allPlayers,
        strategyType: strategyType,
        playersPerTeam: playersPerTeam,
        includeGoalkeepers: includeGoalkeepers,
      );
      state = state.copyWith(teamGenOptions: options, mutating: false);
    } catch (e) {
      state = state.copyWith(
          mutating: false, error: extractDioError(e, 'Falha ao gerar times.'));
    }
  }

  void selectTeamGenOption(int idx) {
    state = state.copyWith(selectedTeamGenIdx: idx);
  }

  void editTeamGenOption(
      int idx, List<TeamGenPlayer> teamA, List<TeamGenPlayer> teamB,
      {List<TeamGenPlayer>? unassigned}) {
    final opts = List<TeamGenOption>.from(state.teamGenOptions);
    if (idx < 0 || idx >= opts.length) return;
    final wA = teamA.fold(0.0, (s, p) => s + p.weight);
    final wB = teamB.fold(0.0, (s, p) => s + p.weight);
    opts[idx] = TeamGenOption(
      teamA: teamA,
      teamB: teamB,
      unassigned: unassigned ?? opts[idx].unassigned,
      teamAWeight: wA,
      teamBWeight: wB,
      balanceDiff: (wA - wB).abs(),
      attackDiff: opts[idx].attackDiff,
      defenseDiff: opts[idx].defenseDiff,
      physicalDiff: opts[idx].physicalDiff,
      explanation: opts[idx].explanation,
    );
    state = state.copyWith(teamGenOptions: opts);
  }

  Future<void> assignTeamsFromGenerated() async {
    final matchId = state.matchId;
    if (matchId == null || state.teamGenOptions.isEmpty) return;
    final idx =
        state.selectedTeamGenIdx.clamp(0, state.teamGenOptions.length - 1);
    final opt = state.teamGenOptions[idx];
    final teamAIds = opt.teamA.map((p) => p.playerId).toList();
    final teamBIds = opt.teamB.map((p) => p.playerId).toList();
    state = state.copyWith(mutating: true);
    try {
      await _ds.assignTeams(groupId, matchId, teamAIds, teamBIds);
      state = state.copyWith(teamGenOptions: [], selectedTeamGenIdx: 0);
      await refresh();
    } catch (e) {
      state =
          state.copyWith(error: extractDioError(e, 'Falha ao atribuir times.'));
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<void> setColors(String teamAColorId, String teamBColorId) async {
    final matchId = state.matchId;
    if (matchId == null) return;
    state = state.copyWith(mutating: true);
    try {
      await _ds.setColors(groupId, matchId, teamAColorId, teamBColorId);
      await refresh();
    } catch (e) {
      state =
          state.copyWith(error: extractDioError(e, 'Falha ao definir cores.'));
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<void> setColorsRandom() async {
    final colors = state.availableColors;
    if (colors.length < 2) return;
    final shuffled = [...colors]..shuffle();
    final a = shuffled[0];
    final b =
        shuffled.firstWhere((c) => c.id != a.id, orElse: () => shuffled[1]);
    await setColors(a.id, b.id);
  }

  Future<void> movePlayerToOtherTeam(String playerId, bool fromTeamA) async {
    final matchId = state.matchId;
    if (matchId == null) return;
    final aIds = state.teamAPlayers.map((p) => p.playerId).toList();
    final bIds = state.teamBPlayers.map((p) => p.playerId).toList();
    final newA = fromTeamA ? (aIds..remove(playerId)) : [...aIds, playerId];
    final newB = fromTeamA ? [...bIds, playerId] : (bIds..remove(playerId));
    state = state.copyWith(mutating: true);
    try {
      await _ds.assignTeams(groupId, matchId, newA, newB);
      await refresh();
    } catch (e) {
      state =
          state.copyWith(error: extractDioError(e, 'Falha ao mover jogador.'));
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<void> assignUnassigned(String playerId, bool toTeamA) async {
    final matchId = state.matchId;
    if (matchId == null) return;
    final aIds = state.teamAPlayers.map((p) => p.playerId).toList();
    final bIds = state.teamBPlayers.map((p) => p.playerId).toList();
    final newA = toTeamA ? [...aIds, playerId] : aIds;
    final newB = toTeamA ? bIds : [...bIds, playerId];
    state = state.copyWith(mutating: true);
    try {
      await _ds.assignTeams(groupId, matchId, newA, newB);
      await refresh();
    } catch (e) {
      state = state.copyWith(
          error: extractDioError(e, 'Falha ao atribuir jogador.'));
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<void> swapPlayers(String playerAId, String playerBId) async {
    final matchId = state.matchId;
    if (matchId == null) return;
    state = state.copyWith(mutating: true);
    try {
      await _ds.swapPlayers(groupId, matchId, playerAId, playerBId);
      await refresh();
    } catch (e) {
      state = state.copyWith(
          error: extractDioError(e, 'Falha ao trocar jogadores.'));
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  /// Também é ação por linha — segue a mesma regra do aceite/recusa e trava
  /// apenas o jogador afetado. A chave aqui é o `matchPlayerId`, que convive
  /// com os `playerId` no mesmo conjunto: são ids distintos, sem colisão.
  Future<void> setPlayerRole(String matchPlayerId, bool isGoalkeeper) async {
    if (state.matchId == null) return;
    if (state.pendingPlayerIds.contains(matchPlayerId)) return;

    _setPlayerPending(matchPlayerId, true);
    try {
      await _ds.setPlayerRole(
          groupId, state.matchId!, matchPlayerId, isGoalkeeper);
      await refresh();
    } catch (e) {
      state = state.copyWith(
          error: extractDioError(e, 'Falha ao alterar função do jogador.'));
    } finally {
      _setPlayerPending(matchPlayerId, false);
    }
  }

  // ── Step 4 – Jogo ─────────────────────────────────────────────────────────

  Future<void> startMatch() async {
    final matchId = state.matchId;
    if (matchId == null) return;
    state = state.copyWith(mutating: true);
    try {
      await _ds.startMatch(groupId, matchId);
      await _loadStepPayload(matchId, MatchStep.playing);
    } catch (e) {
      state = state.copyWith(
          error: extractDioError(e, 'Falha ao iniciar partida.'));
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<void> publishEvent(String eventType) async {
    final matchId = state.matchId;
    if (matchId == null) return;
    await _ds.publishMatchEvent(groupId, matchId, {'type': eventType});
    await _loadStepPayload(matchId, state.step);
  }

  Future<void> addGoal({
    required String scorerPlayerId,
    String? assistPlayerId,
    required String time,
    bool isOwnGoal = false,
  }) async {
    final matchId = state.matchId;
    if (matchId == null) return;
    state = state.copyWith(mutating: true);
    try {
      await _ds.addGoal(
        groupId,
        matchId,
        scorerPlayerId: scorerPlayerId,
        assistPlayerId: assistPlayerId,
        time: time,
        isOwnGoal: isOwnGoal,
      );
      await refresh();
    } catch (e) {
      state =
          state.copyWith(error: extractDioError(e, 'Falha ao adicionar gol.'));
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<void> removeGoal(String goalId) async {
    final matchId = state.matchId;
    if (matchId == null) return;
    state = state.copyWith(mutating: true);
    try {
      await _ds.removeGoal(groupId, matchId, goalId);
      await refresh();
    } catch (e) {
      state =
          state.copyWith(error: extractDioError(e, 'Falha ao remover gol.'));
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<void> updateGoal({
    required String goalId,
    required String scorerPlayerId,
    String? assistPlayerId,
    required String time,
    required bool isOwnGoal,
  }) async {
    final matchId = state.matchId;
    if (matchId == null) return;
    state = state.copyWith(mutating: true);
    try {
      await _ds.updateGoal(groupId, matchId, goalId, {
        'scorerPlayerId': scorerPlayerId,
        if (assistPlayerId != null) 'assistPlayerId': assistPlayerId,
        'time': time,
        'isOwnGoal': isOwnGoal,
      });
      await refresh();
    } catch (e) {
      state =
          state.copyWith(error: extractDioError(e, 'Falha ao atualizar gol.'));
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<bool> endMatch() async {
    final matchId = state.matchId;
    if (matchId == null) return false;
    state = state.copyWith(mutating: true);
    try {
      await _ds.endMatch(groupId, matchId);
      await _loadStepPayload(matchId, MatchStep.ended);
      return true;
    } catch (e) {
      state = state.copyWith(
          error: extractDioError(e, 'Falha ao encerrar partida.'));
      return false;
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  // ── Step 5 – Encerrar ─────────────────────────────────────────────────────

  Future<bool> goToPostGame() async {
    final matchId = state.matchId;
    if (matchId == null) return false;
    state = state.copyWith(mutating: true);
    try {
      await _ds.goToPostGame(groupId, matchId);
      await _loadStepPayload(matchId, MatchStep.post);
      return true;
    } catch (e) {
      state = state.copyWith(
          error: extractDioError(e, 'Falha ao ir para pós-jogo.'));
      return false;
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  // ── Step 6 – Pós-jogo ─────────────────────────────────────────────────────

  Future<void> setScore(int teamAGoals, int teamBGoals) async {
    final matchId = state.matchId;
    if (matchId == null) return;
    state = state.copyWith(mutating: true);
    try {
      await _ds.setScore(groupId, matchId, teamAGoals, teamBGoals);
      await refresh();
    } catch (e) {
      state = state.copyWith(
          error: extractDioError(e, 'Falha ao registrar placar.'));
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<bool> voteMvp(String voterMpId, String votedMpId) async {
    final matchId = state.matchId;
    if (matchId == null) return false;
    state = state.copyWith(mutating: true);
    try {
      await _ds.voteMvp(groupId, matchId, voterMpId, votedMpId);
      await refresh();
      return true;
    } catch (e) {
      state =
          state.copyWith(error: extractDioError(e, 'Falha ao registrar voto.'));
      return false;
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<bool> finalizeMatch() async {
    final matchId = state.matchId;
    if (matchId == null) return false;
    state = state.copyWith(mutating: true);
    try {
      await _ds.finalizeMatch(groupId, matchId);
      await _loadStepPayload(matchId, MatchStep.done);
      return true;
    } catch (e) {
      state = state.copyWith(
          error: extractDioError(e, 'Falha ao finalizar partida.'));
      return false;
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  // ── Admin – voltar etapa ──────────────────────────────────────────────────

  Future<void> rewindStep() async {
    final matchId = state.matchId;
    // Defesa adicional: somente a formação de times pode voltar para a
    // aceitação. Em especial, aceitação jamais retorna para criação.
    if (matchId == null || state.step != MatchStep.teams || !state.canRewind) {
      return;
    }
    state = state.copyWith(mutating: true);
    try {
      await _ds.rewindStep(groupId, matchId);
      await refresh();
    } catch (e) {
      state =
          state.copyWith(error: extractDioError(e, 'Falha ao voltar etapa.'));
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  /// Limpa o erro exibido.
  void clearError() => state = state.copyWith(error: null);

  // ── Excluir partida ──────────────────────────────────────────────────────

  Future<void> deleteMatch() async {
    final matchId = state.matchId;
    if (matchId == null || matchId.isEmpty) return;
    state = state.copyWith(mutating: true, error: null);
    try {
      await _ds.deleteMatch(groupId, matchId);
      await loadInitial();
    } catch (e) {
      state = state.copyWith(
          error: extractDioError(e, 'Falha ao excluir partida.'));
    } finally {
      // Mesmo caso do `createMatch`: no sucesso o `mutating` ficava preso e a
      // tela de criar partida, para onde a exclusão leva de volta, abria com o
      // botão "Criar Partida" girando e inerte.
      state = state.copyWith(mutating: false);
    }
  }

  // ── Multi-match ───────────────────────────────────────────────────────────

  /// Carrega a lista de partidas não-finalizadas.
  Future<void> loadUpcoming() async {
    if (groupId.isEmpty) return;
    try {
      final headers = await _ds.fetchUpcomingMatches(groupId);
      state = state.copyWith(upcomingHeaders: headers);
      // Seleciona a primeira partida se não houver seleção
      if (headers.isNotEmpty && !state.hasMatch) {
        await selectMatch(0);
      }
    } catch (_) {
      // best-effort; não bloqueia o carregamento
    }
  }

  /// Limpa a seleção atual para permitir criar uma nova partida.
  void clearSelection() {
    state = state.copyWith(
      matchId: null,
      step: MatchStep.create,
      selectedMatchIdx: -1,
      linkedPollId: null,
      placeName: state.groupSettings?.defaultPlaceName,
    );
  }

  /// Seleciona uma das partidas da lista /upcoming pelo índice.
  Future<void> selectMatch(int idx) async {
    final headers = state.upcomingHeaders;
    if (idx < 0 || idx >= headers.length) return;
    final header = headers[idx];
    state = state.copyWith(
      selectedMatchIdx: idx,
      matchId: header.matchId,
      step: header.step,
      placeName: header.placeName,
      canRewind: header.canRewind,
      teamAGoals: header.teamAGoals,
      teamBGoals: header.teamBGoals,
      linkedPollId: header.linkedPollId,
      actualStartTime: header.actualStartTime,
    );
    await _loadStepPayload(header.matchId, header.step);
  }

  // ── No-show / DidNotPlay ──────────────────────────────────────────────────

  /// Marca ou desmarca um jogador como "não foi jogar".
  Future<void> setNoShow(String matchPlayerId, bool didNotPlay) async {
    final matchId = state.matchId;
    if (matchId == null) return;
    state = state.copyWith(mutating: true);
    try {
      await _ds.setNoShow(groupId, matchId, matchPlayerId, didNotPlay);
      await refresh();
    } catch (e) {
      state = state.copyWith(
          error: extractDioError(e, 'Falha ao marcar ausência.'));
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  // ── Vínculo Partida ↔ Votação ─────────────────────────────────────────────

  /// Vincula ou desvincula uma votação/evento a esta partida.
  Future<void> setLinkedPoll(String? pollId) async {
    final matchId = state.matchId;
    if (matchId == null) return;
    state = state.copyWith(mutating: true);
    try {
      await _ds.setLinkedPoll(groupId, matchId, pollId);
      state = state.copyWith(linkedPollId: pollId);
    } catch (e) {
      state = state.copyWith(
          error: extractDioError(e, 'Falha ao vincular votação.'));
    } finally {
      state = state.copyWith(mutating: false);
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final matchNotifierProvider =
    StateNotifierProvider.autoDispose<MatchNotifier, MatchState>((ref) {
  final acc = ref.watch(accountStoreProvider.select((s) => s.activeAccount));
  final player = ref.watch(activePlayerProvider);
  final groupId = acc?.activeGroupId ?? player?.groupId ?? '';
  final isAdmin = groupId.isNotEmpty && (acc?.isGroupAdmin(groupId) ?? false);
  return MatchNotifier(ref.read(matchDsProvider), groupId, isAdmin);
});

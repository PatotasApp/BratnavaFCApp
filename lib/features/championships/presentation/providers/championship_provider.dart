import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_constants.dart';
import '../../../../core/api/api_response.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../data/datasources/championship_api_datasource.dart';
import '../../data/datasources/championship_datasource.dart';
import '../../data/datasources/championship_mock_datasource.dart';
import '../../domain/entities/championship_enums.dart';
import '../../domain/entities/championship_models.dart';

final championshipDataSourceProvider = Provider<ChampionshipDataSource>((ref) {
  if (AppConstants.championshipsUseMock) {
    return ChampionshipMockDataSource();
  }
  return ChampionshipApiDataSource(ref.watch(dioProvider));
});

final championshipGroupIdProvider = Provider<String>((ref) {
  final account = ref.watch(accountStoreProvider).activeAccount;
  final player = ref.watch(activePlayerProvider);
  return account?.activeGroupId ?? player?.groupId ?? '';
});

final championshipIsAdminProvider = Provider<bool>((ref) {
  final account = ref.watch(accountStoreProvider).activeAccount;
  final groupId = ref.watch(championshipGroupIdProvider);
  return groupId.isNotEmpty && (account?.isGroupAdmin(groupId) ?? false);
});

/// Jogador da patota para o seletor de convidado.
typedef ChampionshipGroupPlayer = ({String id, String name, bool isGuest});

/// Jogadores da patota pelo mesmo `GET /api/Groups/{id}` que o team builder
/// usa. O convidado do campeonato tem de ser jogador já cadastrado.
final championshipGroupPlayersProvider = FutureProvider.autoDispose
    .family<List<ChampionshipGroupPlayer>, String>((ref, groupId) async {
  if (AppConstants.championshipsUseMock) {
    return [
      for (var index = 1; index <= 4; index++)
        (id: 'mock-guest-$index', name: 'Convidado $index', isGuest: true),
    ];
  }
  final response =
      await ref.watch(dioProvider).get(ApiConstants.groupById(groupId));
  final body = unwrapMap(response.data);
  final players = (body?['players'] as List<dynamic>? ?? [])
      .whereType<Map<String, dynamic>>()
      .where((player) => player['status'] != 'Inactive')
      .map((player) => (
            id: (player['id'] ?? player['playerId'] ?? '').toString(),
            name: (player['name'] ?? player['playerName'] ?? '').toString(),
            isGuest: player['isGuest'] == true,
          ))
      .where((player) => player.id.isNotEmpty)
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return players;
});

/// Campeonatos que aparecem no dashboard, como a próxima partida: os que ainda
/// não terminaram (de Criado até a votação do MVP). O ao vivo vem primeiro,
/// depois a etapa mais adiantada; empate pela data.
final dashboardChampionshipsProvider = FutureProvider.autoDispose
    .family<List<ChampionshipDetails>, String>((ref, groupId) async {
  if (!AppConstants.championshipsEnabled || groupId.isEmpty) return const [];
  const priority = [
    ChampionshipStatus.inProgress,
    ChampionshipStatus.postGame,
    ChampionshipStatus.teamDraw,
    ChampionshipStatus.acceptation,
    ChampionshipStatus.created,
  ];
  final dataSource = ref.watch(championshipDataSourceProvider);
  final active = (await dataSource.fetchAll(groupId))
      .where((item) => priority.contains(item.status))
      .toList()
    ..sort((a, b) {
      final byStatus =
          priority.indexOf(a.status).compareTo(priority.indexOf(b.status));
      return byStatus != 0 ? byStatus : a.playedAt.compareTo(b.playedAt);
    });
  return Future.wait([
    for (final item in active) dataSource.fetchById(groupId, item.id),
  ]);
});

class ChampionshipListState {
  const ChampionshipListState({
    this.loading = false,
    this.mutating = false,
    this.items = const [],
    this.error,
  });

  final bool loading;
  final bool mutating;
  final List<ChampionshipSummary> items;
  final String? error;

  ChampionshipListState copyWith({
    bool? loading,
    bool? mutating,
    List<ChampionshipSummary>? items,
    String? error,
    bool clearError = false,
  }) =>
      ChampionshipListState(
        loading: loading ?? this.loading,
        mutating: mutating ?? this.mutating,
        items: items ?? this.items,
        error: clearError ? null : error ?? this.error,
      );
}

class ChampionshipListNotifier extends StateNotifier<ChampionshipListState> {
  ChampionshipListNotifier(this._dataSource, this.groupId)
      : super(const ChampionshipListState());

  final ChampionshipDataSource _dataSource;
  final String groupId;

  Future<void> load() async {
    if (groupId.isEmpty) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      state = state.copyWith(items: await _dataSource.fetchAll(groupId));
    } catch (error) {
      state = state.copyWith(
        error: extractDioError(error, 'Falha ao carregar campeonatos.'),
      );
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<String?> create(ChampionshipUpsert input) async {
    state = state.copyWith(mutating: true, clearError: true);
    try {
      final id = await _dataSource.create(groupId, input);
      await load();
      return id;
    } catch (error) {
      state = state.copyWith(
        error: extractDioError(error, 'Falha ao criar campeonato.'),
      );
      return null;
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final championshipListProvider = StateNotifierProvider.autoDispose<
    ChampionshipListNotifier, ChampionshipListState>((ref) {
  final notifier = ChampionshipListNotifier(
    ref.watch(championshipDataSourceProvider),
    ref.watch(championshipGroupIdProvider),
  );
  Future.microtask(notifier.load);
  return notifier;
});

class ChampionshipDetailsState {
  const ChampionshipDetailsState({
    this.loading = false,
    this.mutating = false,
    this.details,
    this.nextGame,
    this.error,
  });

  final bool loading;
  final bool mutating;
  final ChampionshipDetails? details;
  final NextGameSuggestion? nextGame;
  final String? error;

  ChampionshipDetailsState copyWith({
    bool? loading,
    bool? mutating,
    ChampionshipDetails? details,
    NextGameSuggestion? nextGame,
    bool clearNextGame = false,
    String? error,
    bool clearError = false,
  }) =>
      ChampionshipDetailsState(
        loading: loading ?? this.loading,
        mutating: mutating ?? this.mutating,
        details: details ?? this.details,
        nextGame: clearNextGame ? null : nextGame ?? this.nextGame,
        error: clearError ? null : error ?? this.error,
      );
}

class ChampionshipDetailsNotifier
    extends StateNotifier<ChampionshipDetailsState> {
  ChampionshipDetailsNotifier(
    this._dataSource,
    this.groupId,
    this.championshipId,
  ) : super(const ChampionshipDetailsState());

  final ChampionshipDataSource _dataSource;
  final String groupId;
  final String championshipId;

  Future<void> load({bool silent = false}) async {
    if (groupId.isEmpty) return;
    if (!silent) state = state.copyWith(loading: true, clearError: true);
    try {
      final details = await _dataSource.fetchById(groupId, championshipId);
      NextGameSuggestion? suggestion;
      if (details.status == ChampionshipStatus.inProgress) {
        suggestion = await _dataSource.fetchNextGame(
          groupId,
          championshipId,
        );
      }
      state = state.copyWith(
        details: details,
        nextGame: suggestion,
        clearNextGame: suggestion == null,
      );
    } catch (error) {
      if (!silent) {
        state = state.copyWith(
          error: extractDioError(error, 'Falha ao carregar campeonato.'),
        );
      }
    } finally {
      if (!silent) state = state.copyWith(loading: false);
    }
  }

  Future<bool> _mutate(
    Future<void> Function() action,
    String errorMessage,
  ) async {
    state = state.copyWith(mutating: true, clearError: true);
    try {
      await action();
      await load(silent: true);
      return true;
    } catch (error) {
      state = state.copyWith(error: extractDioError(error, errorMessage));
      return false;
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<bool> update(ChampionshipUpsert input) => _mutate(
        () => _dataSource.update(groupId, championshipId, input),
        'Falha ao atualizar campeonato.',
      );
  Future<bool> cancel() => _mutate(
        () => _dataSource.cancel(groupId, championshipId),
        'Falha ao cancelar campeonato.',
      );
  Future<bool> openAcceptation() => _mutate(
        () => _dataSource.openAcceptation(groupId, championshipId),
        'Falha ao abrir presença.',
      );
  Future<bool> acceptMyInvite() => _mutate(
        () => _dataSource.acceptMyInvite(groupId, championshipId),
        'Falha ao confirmar presença.',
      );
  Future<bool> rejectMyInvite() => _mutate(
        () => _dataSource.rejectMyInvite(groupId, championshipId),
        'Falha ao recusar presença.',
      );
  Future<bool> setInvite(String playerId, {required bool accepted}) => _mutate(
        () => accepted
            ? _dataSource.acceptInvite(groupId, championshipId, playerId)
            : _dataSource.rejectInvite(groupId, championshipId, playerId),
        'Falha ao alterar presença.',
      );
  Future<bool> addNewGuest({
    required String name,
    required bool isGoalkeeper,
    int? starRating,
  }) =>
      _mutate(
        () => _dataSource.addNewGuest(
          groupId,
          championshipId,
          name: name,
          isGoalkeeper: isGoalkeeper,
          starRating: starRating,
        ),
        'Falha ao adicionar convidado.',
      );
  Future<bool> addGuest(String playerId) => _mutate(
        () => _dataSource.addGuest(groupId, championshipId, playerId),
        'Falha ao adicionar convidado.',
      );
  Future<ChampionshipTeamsDraw?> drawTeams(int teamCount) async {
    state = state.copyWith(mutating: true, clearError: true);
    try {
      return await _dataSource.drawTeams(
        groupId,
        championshipId,
        teamCount,
      );
    } catch (error) {
      state = state.copyWith(
        error: extractDioError(error, 'Falha ao sortear times.'),
      );
      return null;
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<bool> defineTeams(DefineChampionshipTeams input) => _mutate(
        () => _dataSource.defineTeams(
          groupId,
          championshipId,
          input,
        ),
        'Falha ao definir times.',
      );
  Future<bool> assignPlayerTeam(String playerId, String teamId) => _mutate(
        () => _dataSource.assignPlayerTeam(
          groupId,
          championshipId,
          playerId,
          teamId,
        ),
        'Falha ao trocar jogador de time.',
      );

  /// Devolve a mensagem para mostrar ao admin, ou null se falhou.
  Future<String?> drawTeamColors() async {
    String? message;
    final ok = await _mutate(
      () async => message = await _dataSource.drawTeamColors(
        groupId,
        championshipId,
      ),
      'Falha ao sortear cores.',
    );
    return ok ? (message ?? 'Cores sorteadas.') : null;
  }

  Future<bool> updateTeam(
    String teamId, {
    required String name,
    String? colorId,
  }) =>
      _mutate(
        () => _dataSource.updateTeam(
          groupId,
          championshipId,
          teamId,
          name: name,
          colorId: colorId,
        ),
        'Falha ao atualizar time.',
      );
  Future<bool> stepBack() => _mutate(
        () => _dataSource.stepBack(groupId, championshipId),
        'Falha ao voltar etapa.',
      );
  Future<bool> start() => _mutate(
        () => _dataSource.start(groupId, championshipId),
        'Falha ao iniciar campeonato.',
      );
  Future<bool> createSuggestedGame() {
    final suggestion = state.nextGame;
    if (suggestion == null) return Future.value(false);
    return _mutate(
      () => _dataSource.createGame(
        groupId,
        championshipId,
        suggestion.teamAId,
        suggestion.teamBId,
      ),
      'Falha ao criar próximo jogo.',
    );
  }

  Future<bool> addGoal({
    required String gameId,
    required String scorerPlayerId,
    String? assistPlayerId,
    bool isOwnGoal = false,
    int? timeSeconds,
  }) =>
      _mutate(
        () => _dataSource.addGoal(
          groupId,
          championshipId,
          gameId,
          scorerPlayerId: scorerPlayerId,
          assistPlayerId: assistPlayerId,
          isOwnGoal: isOwnGoal,
          timeSeconds: timeSeconds,
        ),
        'Falha ao registrar gol.',
      );
  Future<bool> deleteGoal(String gameId, String goalId) => _mutate(
        () => _dataSource.deleteGoal(
          groupId,
          championshipId,
          gameId,
          goalId,
        ),
        'Falha ao remover gol.',
      );
  Future<bool> setGoalkeeper(
    String teamId,
    String playerId,
  ) =>
      _mutate(
        () => _dataSource.setGoalkeeper(
          groupId,
          championshipId,
          teamId,
          playerId,
        ),
        'Falha ao definir goleiro.',
      );
  Future<bool> endGame(String gameId, {String? externalWinnerTeamId}) =>
      _mutate(
        () => _dataSource.endGame(
          groupId,
          championshipId,
          gameId,
          externalWinnerTeamId: externalWinnerTeamId,
        ),
        'Falha ao encerrar jogo.',
      );

  /// Troca 2 jogadores de lugar. Em times diferentes, cada um vai para o time
  /// do outro e quem chega assume o papel de goleiro de quem saiu. No mesmo
  /// time, o goleiro passa para o outro.
  Future<bool> swapPlayers(String firstId, String secondId) {
    final details = state.details;
    if (details == null) return Future.value(false);
    final first = details.playerById(firstId);
    final second = details.playerById(secondId);
    final firstTeam = first?.teamId;
    final secondTeam = second?.teamId;
    if (first == null || second == null) return Future.value(false);
    return _mutate(() async {
      if (firstTeam != null && firstTeam == secondTeam) {
        if (first.isGoalkeeper != second.isGoalkeeper) {
          await _dataSource.setGoalkeeper(
            groupId,
            championshipId,
            firstTeam,
            first.isGoalkeeper ? secondId : firstId,
          );
        }
        return;
      }
      if (secondTeam != null) {
        await _dataSource.assignPlayerTeam(
            groupId, championshipId, firstId, secondTeam);
      }
      if (firstTeam != null) {
        await _dataSource.assignPlayerTeam(
            groupId, championshipId, secondId, firstTeam);
      }
      // Reafirma o goleiro dos dois times para quem saiu não continuar
      // marcado como goleiro no time novo.
      String? goalkeeperOf(String teamId) {
        for (final player in details.players) {
          if (player.teamId == teamId && player.isGoalkeeper) {
            return player.playerId;
          }
        }
        return null;
      }

      if (firstTeam != null) {
        final keeper = first.isGoalkeeper ? secondId : goalkeeperOf(firstTeam);
        if (keeper != null) {
          await _dataSource.setGoalkeeper(
              groupId, championshipId, firstTeam, keeper);
        }
      }
      if (secondTeam != null) {
        final keeper = second.isGoalkeeper ? firstId : goalkeeperOf(secondTeam);
        if (keeper != null) {
          await _dataSource.setGoalkeeper(
              groupId, championshipId, secondTeam, keeper);
        }
      }
    }, 'Falha ao trocar jogadores.');
  }

  Future<bool> publishGameEvent(String gameId, String type) => _mutate(
        () => _dataSource.publishGameEvent(
          groupId,
          championshipId,
          gameId,
          type,
        ),
        'Falha ao marcar o lance.',
      );
  Future<bool> finish() => _mutate(
        () => _dataSource.finish(groupId, championshipId),
        'Falha ao encerrar campeonato.',
      );
  Future<bool> vote(String playerId, {String? gameId}) => _mutate(
        () => _dataSource.vote(
          groupId,
          championshipId,
          playerId,
          gameId: gameId,
        ),
        'Falha ao registrar voto.',
      );
  Future<bool> finalize({List<String>? externalDecisionTeamOrder}) => _mutate(
        () => _dataSource.finalize(
          groupId,
          championshipId,
          externalDecisionTeamOrder: externalDecisionTeamOrder,
        ),
        'Falha ao finalizar campeonato.',
      );

  void clearError() => state = state.copyWith(clearError: true);
}

final championshipDetailsProvider = StateNotifierProvider.autoDispose
    .family<ChampionshipDetailsNotifier, ChampionshipDetailsState, String>(
  (ref, championshipId) {
    final notifier = ChampionshipDetailsNotifier(
      ref.watch(championshipDataSourceProvider),
      ref.watch(championshipGroupIdProvider),
      championshipId,
    );
    Future.microtask(notifier.load);
    return notifier;
  },
);

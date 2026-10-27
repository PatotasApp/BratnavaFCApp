import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  Future<bool> addGuest(String playerId) => _mutate(
        () => _dataSource.addGuest(groupId, championshipId, playerId),
        'Falha ao adicionar convidado.',
      );
  Future<DefineChampionshipTeams?> drawTeams(int teamCount) async {
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

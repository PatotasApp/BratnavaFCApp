import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/domain/entities/my_player.dart';
import '../../data/datasources/player_history_remote_datasource.dart';
import '../../domain/entities/player_history_models.dart';

// ── DataSource singleton ──────────────────────────────────────────────────────

final _playerHistoryDsProvider = Provider<PlayerHistoryRemoteDataSource>(
  (ref) => PlayerHistoryRemoteDataSource(ref.watch(dioProvider)),
);

// ── My players list (used to populate the selector) ──────────────────────────

final myPlayersProvider = FutureProvider.autoDispose<List<MyPlayer>>(
  (ref) => ref.watch(_playerHistoryDsProvider).fetchMyPlayers(),
);

// ── History query params ──────────────────────────────────────────────────────

typedef PlayerHistoryArgs = ({String groupId, String playerId, int? year});

// ── History list ──────────────────────────────────────────────────────────────

final playerHistoryProvider = FutureProvider.autoDispose
    .family<List<MatchHistoryItem>, PlayerHistoryArgs>(
  (ref, args) => ref.watch(_playerHistoryDsProvider).fetchPlayerHistory(
        groupId: args.groupId,
        playerId: args.playerId,
        year: args.year,
      ),
);

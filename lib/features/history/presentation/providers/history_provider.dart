import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/history_remote_datasource.dart';
import '../../domain/entities/history_match.dart';
import '../../domain/entities/match_details.dart';

// ── DataSource ────────────────────────────────────────────────────────────────

final historyDsProvider = Provider<HistoryRemoteDataSource>(
  (ref) => HistoryRemoteDataSource(ref.watch(dioProvider)),
);

// Keep private alias for internal use
final _historyDsProvider = historyDsProvider;

// ── History list ──────────────────────────────────────────────────────────────

final historyProvider =
    FutureProvider.autoDispose.family<List<HistoryMatch>, String>(
  (ref, groupId) {
    final ds = ref.watch(_historyDsProvider);
    return ds.fetchHistory(groupId);
  },
);

typedef HistoryPageArgs = ({
  String groupId,
  int page,
  int pageSize,
  String? playerId,
});

final historyPageProvider =
    FutureProvider.autoDispose.family<PagedHistoryMatches, HistoryPageArgs>(
  (ref, args) {
    final ds = ref.watch(_historyDsProvider);
    return ds.fetchHistoryPage(
      args.groupId,
      page: args.page,
      pageSize: args.pageSize,
      playerId: args.playerId,
    );
  },
);

// ── My match IDs (for "only my matches" filter) ──────────────────────────────

typedef MyMatchIdsArgs = ({String groupId, String playerId});

final myMatchIdsProvider =
    FutureProvider.autoDispose.family<Set<String>, MyMatchIdsArgs>(
  (ref, args) => ref
      .watch(_historyDsProvider)
      .fetchMyMatchIds(args.groupId, args.playerId),
);

// ── Match details ─────────────────────────────────────────────────────────────

final matchDetailsProvider = FutureProvider.autoDispose
    .family<MatchDetails, ({String groupId, String matchId})>(
  (ref, args) {
    final ds = ref.watch(_historyDsProvider);
    return ds.fetchMatchDetails(args.groupId, args.matchId);
  },
);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/polls_remote_datasource.dart';
import '../../domain/entities/poll_summary.dart';

final pollsDsProvider = Provider<PollsRemoteDataSource>(
  (ref) => PollsRemoteDataSource(ref.watch(dioProvider)),
);

final pollsListProvider =
    FutureProvider.autoDispose.family<List<PollSummary>, String>(
  (ref, groupId) => ref.watch(pollsDsProvider).getPolls(groupId),
);

final pendingPollsCountProvider =
    FutureProvider.autoDispose.family<int, String>(
  (ref, groupId) async {
    final list = await ref.watch(pollsListProvider(groupId).future);
    return list
        .where((p) => p.isOpen && !p.hasVoted && !p.deadlinePassed)
        .length;
  },
);

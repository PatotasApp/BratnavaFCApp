import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/retrospective_remote_datasource.dart';
import '../../domain/entities/player_retrospective.dart';

final _retrospectiveDsProvider = Provider<RetrospectiveRemoteDataSource>(
  (ref) => RetrospectiveRemoteDataSource(ref.watch(dioProvider)),
);

typedef RetrospectiveQuery = ({String groupId, String? playerId, int? year});

final retrospectiveProvider =
    FutureProvider.autoDispose.family<PlayerRetrospective, RetrospectiveQuery>(
  (ref, q) => ref
      .watch(_retrospectiveDsProvider)
      .fetch(q.groupId, playerId: q.playerId, year: q.year),
);

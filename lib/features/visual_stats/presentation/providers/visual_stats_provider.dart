import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/visual_stats_datasource.dart';
import '../../domain/entities/visual_stats_report.dart';

final visualStatsDsProvider = Provider<VisualStatsDatasource>(
  (ref) => VisualStatsDatasource(ref.watch(dioProvider)),
);

final visualStatsProvider =
    FutureProvider.autoDispose.family<PlayerVisualStatsReport, String>(
  (ref, groupId) => ref.watch(visualStatsDsProvider).fetchVisualStats(groupId),
);

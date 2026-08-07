import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/spotlight_remote_datasource.dart';
import '../../domain/entities/spotlight_report.dart';

final _spotlightDsProvider = Provider<SpotlightRemoteDataSource>(
  (ref) => SpotlightRemoteDataSource(ref.watch(dioProvider)),
);

final spotlightProvider =
    FutureProvider.autoDispose.family<PlayerSpotlightReport, String>(
  (ref, groupId) => ref.watch(_spotlightDsProvider).fetchSpotlight(groupId),
);

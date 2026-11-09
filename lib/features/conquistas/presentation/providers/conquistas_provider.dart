import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/conquistas_remote_datasource.dart';
import '../../domain/entities/conquista_models.dart';

final _conquistasDataSourceProvider = Provider<ConquistasRemoteDataSource>(
  (ref) => ConquistasRemoteDataSource(ref.watch(dioProvider)),
);

typedef GroupConquistasArgs = ({String groupId, String? seasonId});

final groupConquistasProvider =
    FutureProvider.autoDispose.family<GroupConquistas, GroupConquistasArgs>(
  (ref, args) => ref
      .watch(_conquistasDataSourceProvider)
      .fetchGroup(args.groupId, seasonId: args.seasonId),
);

final publicProfileProvider =
    FutureProvider.autoDispose.family<UserPublicProfile, String>(
  (ref, userId) =>
      ref.watch(_conquistasDataSourceProvider).fetchProfile(userId),
);

final profilePrivacyProvider = FutureProvider.autoDispose<ProfilePrivacy>(
  (ref) => ref.watch(_conquistasDataSourceProvider).fetchPrivacy(),
);

Future<ProfilePrivacy> saveProfilePrivacy(
  WidgetRef ref,
  ProfilePrivacy privacy,
) async {
  final result =
      await ref.read(_conquistasDataSourceProvider).updatePrivacy(privacy);
  ref.invalidate(profilePrivacyProvider);
  return result;
}

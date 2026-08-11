import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/conquistas_remote_datasource.dart';
import '../../domain/entities/conquista_models.dart';

final _conquistasDataSourceProvider = Provider<ConquistasRemoteDataSource>(
  (ref) => ConquistasRemoteDataSource(ref.watch(dioProvider)),
);

final groupConquistasProvider =
    FutureProvider.autoDispose.family<GroupConquistas, String>(
  (ref, groupId) =>
      ref.watch(_conquistasDataSourceProvider).fetchGroup(groupId),
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

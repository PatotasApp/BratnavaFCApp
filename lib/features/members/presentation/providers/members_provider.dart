import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/members_remote_datasource.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/group_player.dart';

final membersDsProvider = Provider<MembersRemoteDataSource>(
  (ref) => MembersRemoteDataSource(ref.watch(dioProvider)),
);

// ── Users (admin listing) ─────────────────────────────────────────────────────

final usersProvider = FutureProvider.autoDispose<List<AppUser>>((ref) {
  final ds = ref.watch(membersDsProvider);
  return ds.fetchUsers();
});

// ── My profile (non-admin) ────────────────────────────────────────────────────

final myProfileProvider = FutureProvider.autoDispose<AppUser>((ref) async {
  final account = ref.watch(accountStoreProvider).activeAccount;
  if (account == null) throw Exception('Não autenticado');

  try {
    final ds = ref.watch(membersDsProvider);
    return await ds.fetchUserById(account.userId);
  } catch (_) {
    // Fallback: construct AppUser from account data
    final parts = account.name.trim().split(' ');
    return AppUser(
      id: account.userId,
      firstName: parts.isNotEmpty ? parts.first : '',
      lastName: parts.length > 1 ? parts.skip(1).join(' ') : '',
      email: account.email,
      userName: account.email.split('@').first,
      roles: account.roles,
      isActive: true,
    );
  }
});

// ── Players (group) ───────────────────────────────────────────────────────────

final playersProvider =
    FutureProvider.autoDispose.family<List<GroupPlayer>, String>(
  (ref, groupId) {
    final ds = ref.watch(membersDsProvider);
    return ds.fetchGroupPlayers(groupId);
  },
);

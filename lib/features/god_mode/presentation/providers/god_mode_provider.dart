import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/god_mode_remote_datasource.dart';
import '../../domain/entities/god_mode_models.dart';

// ── DataSource ────────────────────────────────────────────────────────────────

final godModeDsProvider = Provider<GodModeRemoteDataSource>(
  (ref) => GodModeRemoteDataSource(ref.watch(dioProvider)),
);

// ── User filter state ─────────────────────────────────────────────────────────

class UsersFilterParams {
  final String search;
  final UserStatusFilter status;
  final int page;
  final int pageSize;

  const UsersFilterParams({
    this.search = '',
    this.status = UserStatusFilter.all,
    this.page = 1,
    this.pageSize = 20,
  });

  String? get statusParam => switch (status) {
        UserStatusFilter.active => 'active',
        UserStatusFilter.inactive => 'inactive',
        UserStatusFilter.all => null,
      };

  UsersFilterParams copyWith({
    String? search,
    UserStatusFilter? status,
    int? page,
    int? pageSize,
  }) =>
      UsersFilterParams(
        search: search ?? this.search,
        status: status ?? this.status,
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
      );

  @override
  bool operator ==(Object other) =>
      other is UsersFilterParams &&
      other.search == search &&
      other.status == status &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(search, status, page, pageSize);
}

// ── Filter notifier ───────────────────────────────────────────────────────────

class UsersFilterNotifier extends StateNotifier<UsersFilterParams> {
  UsersFilterNotifier() : super(const UsersFilterParams());

  void setSearch(String q) => state = state.copyWith(search: q, page: 1);

  void setStatus(UserStatusFilter s) =>
      state = state.copyWith(status: s, page: 1);

  void setPage(int p) => state = state.copyWith(page: p);

  void reset() => state = const UsersFilterParams();
}

final usersFilterProvider =
    StateNotifierProvider.autoDispose<UsersFilterNotifier, UsersFilterParams>(
  (ref) => UsersFilterNotifier(),
);

// ── Paged users provider ──────────────────────────────────────────────────────

final pagedUsersProvider =
    FutureProvider.autoDispose<PagedResult<UserItemListDto>>((ref) {
  final params = ref.watch(usersFilterProvider);
  final ds = ref.watch(godModeDsProvider);
  return ds.fetchUsers(
    search: params.search,
    status: params.statusParam,
    page: params.page,
    pageSize: params.pageSize,
  );
});

// ── Groups provider ───────────────────────────────────────────────────────────

final godModeGroupsProvider = FutureProvider.autoDispose<List<GroupDto>>((ref) {
  final ds = ref.watch(godModeDsProvider);
  return ds.fetchGroups();
});

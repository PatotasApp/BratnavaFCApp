import 'package:equatable/equatable.dart';

// ── PagedResult ───────────────────────────────────────────────────────────────

class PagedResult<T> extends Equatable {
  final List<T> items;
  final int totalCount;
  final int page;
  final int pageSize;

  const PagedResult({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  bool get hasMore => page * pageSize < totalCount;

  @override
  List<Object?> get props => [items, totalCount, page, pageSize];
}

// ── UserItemListDto ───────────────────────────────────────────────────────────

class UserItemListDto extends Equatable {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String userName;
  final List<String> roles;
  final bool isActive;
  final String? createdAt;

  const UserItemListDto({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.userName,
    required this.roles,
    required this.isActive,
    this.createdAt,
  });

  String get fullName {
    final full = '$firstName $lastName'.trim();
    return full.isNotEmpty ? full : (userName.isNotEmpty ? userName : email);
  }

  factory UserItemListDto.fromJson(Map<String, dynamic> j) => UserItemListDto(
        id: j['id'] as String? ?? '',
        firstName: j['firstName'] as String? ?? '',
        lastName: j['lastName'] as String? ?? '',
        email: j['email'] as String? ?? '',
        userName: j['userName'] as String? ?? j['username'] as String? ?? '',
        roles: j['roles'] is List
            ? List<String>.from((j['roles'] as List).map((e) => e.toString()))
            : const [],
        isActive: j['isActive'] as bool? ?? true,
        createdAt: j['createdAt'] as String?,
      );

  @override
  List<Object?> get props =>
      [id, firstName, lastName, email, userName, roles, isActive, createdAt];
}

// ── GroupDto ──────────────────────────────────────────────────────────────────

class GroupDto extends Equatable {
  final String groupId;
  final String name;
  final bool isActive;
  final String? createdAt;
  final int playerCount;

  const GroupDto({
    required this.groupId,
    required this.name,
    required this.isActive,
    this.createdAt,
    required this.playerCount,
  });

  factory GroupDto.fromJson(Map<String, dynamic> j) => GroupDto(
        groupId: j['groupId'] as String? ?? j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        isActive: j['isActive'] as bool? ?? true,
        createdAt: j['createdAt'] as String?,
        playerCount: j['playerCount'] as int? ?? 0,
      );

  @override
  List<Object?> get props => [groupId, name, isActive, createdAt, playerCount];
}

// ── UserFilter ────────────────────────────────────────────────────────────────

enum UserStatusFilter { all, active, inactive }

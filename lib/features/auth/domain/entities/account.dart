import 'package:equatable/equatable.dart';

class Account extends Equatable {
  final String userId;
  final String name;
  final String email;
  final List<String> roles;
  final String accessToken;
  final String refreshToken;
  final String? activeGroupId;
  final String? activePlayerId;
  final List<String> groupAdminIds;
  final List<String> groupFinanceiroIds;
  final bool?
      activeGroupIsAdmin; // role na patota ATIVA — atualiza a cada troca
  final bool? activeGroupIsFinanceiro; // idem para financeiro
  final bool keepLoggedIn;

  const Account({
    required this.userId,
    required this.name,
    required this.email,
    required this.roles,
    required this.accessToken,
    required this.refreshToken,
    this.activeGroupId,
    this.activePlayerId,
    this.groupAdminIds = const [],
    this.groupFinanceiroIds = const [],
    this.activeGroupIsAdmin,
    this.activeGroupIsFinanceiro,
    this.keepLoggedIn = true,
  });

  // ── RBAC helpers ──────────────────────────────────────────────────────────

  bool get isAdmin => roles.any((r) => r.toLowerCase() == 'admin');

  /// Retorna true se o usuário é admin desta patota.
  /// Para a patota ativa, usa o flag confirmado pelo backend (activeGroupIsAdmin)
  /// como fonte primária; cai no array (populado no login) como fallback.
  bool isGroupAdmin(String groupId) {
    if (groupId == activeGroupId && (activeGroupIsAdmin ?? false)) return true;
    return groupAdminIds.contains(groupId);
  }

  /// Retorna true se o usuário é financeiro desta patota.
  /// Para a patota ativa, usa o flag confirmado pelo backend (activeGroupIsFinanceiro)
  /// como fonte primária; cai no array (populado no login) como fallback.
  bool isGroupFinanceiro(String groupId) {
    if (groupId == activeGroupId && (activeGroupIsFinanceiro ?? false)) {
      return true;
    }
    return groupFinanceiroIds.contains(groupId);
  }

  // Checks para a patota ATIVA — mais seguros que os de array pois vêm do backend
  // no momento da troca. Usam os arrays como fallback enquanto a resposta não chega.
  bool get isActiveGroupAdmin => activeGroupIsAdmin ?? false;
  bool get isActiveGroupFinanceiro => activeGroupIsFinanceiro ?? false;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'email': email,
        'roles': roles,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'activeGroupId': activeGroupId,
        'activePlayerId': activePlayerId,
        'groupAdminIds': groupAdminIds,
        'groupFinanceiroIds': groupFinanceiroIds,
        'activeGroupIsAdmin': activeGroupIsAdmin,
        'activeGroupIsFinanceiro': activeGroupIsFinanceiro,
        'keepLoggedIn': keepLoggedIn,
      };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        userId: json['userId'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        roles: List<String>.from(json['roles'] as List? ?? []),
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        activeGroupId: json['activeGroupId'] as String?,
        activePlayerId: json['activePlayerId'] as String?,
        groupAdminIds: List<String>.from(json['groupAdminIds'] as List? ?? []),
        groupFinanceiroIds:
            List<String>.from(json['groupFinanceiroIds'] as List? ?? []),
        activeGroupIsAdmin: json['activeGroupIsAdmin'] as bool?,
        activeGroupIsFinanceiro: json['activeGroupIsFinanceiro'] as bool?,
        keepLoggedIn: json['keepLoggedIn'] as bool? ?? true,
      );

  Account copyWith({
    String? userId,
    String? name,
    String? email,
    List<String>? roles,
    String? accessToken,
    String? refreshToken,
    String? activeGroupId,
    String? activePlayerId,
    bool clearActiveGroupId = false,
    bool clearActivePlayerId = false,
    List<String>? groupAdminIds,
    List<String>? groupFinanceiroIds,
    bool? activeGroupIsAdmin,
    bool? activeGroupIsFinanceiro,
    bool? keepLoggedIn,
  }) =>
      Account(
        userId: userId ?? this.userId,
        name: name ?? this.name,
        email: email ?? this.email,
        roles: roles ?? this.roles,
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
        activeGroupId:
            clearActiveGroupId ? null : activeGroupId ?? this.activeGroupId,
        activePlayerId:
            clearActivePlayerId ? null : activePlayerId ?? this.activePlayerId,
        groupAdminIds: groupAdminIds ?? this.groupAdminIds,
        groupFinanceiroIds: groupFinanceiroIds ?? this.groupFinanceiroIds,
        activeGroupIsAdmin: activeGroupIsAdmin ?? this.activeGroupIsAdmin,
        activeGroupIsFinanceiro:
            activeGroupIsFinanceiro ?? this.activeGroupIsFinanceiro,
        keepLoggedIn: keepLoggedIn ?? this.keepLoggedIn,
      );

  @override
  List<Object?> get props => [
        userId,
        name,
        email,
        roles,
        accessToken,
        refreshToken,
        activeGroupId,
        activePlayerId,
        groupAdminIds,
        groupFinanceiroIds,
        activeGroupIsAdmin,
        activeGroupIsFinanceiro,
        keepLoggedIn,
      ];
}

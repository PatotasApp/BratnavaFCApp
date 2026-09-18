import 'package:equatable/equatable.dart';

/// Perfil do usuário logado, do lado do app.
///
/// NÃO guarda token: a sessão é do Firebase, que persiste o refresh token no
/// aparelho e emite ID tokens de ~1h sozinho. O que sobra aqui é o que o
/// backend nos conta — a identidade interna e as permissões por patota.
///
/// O [userId] é o GUID interno vindo do `GET /api/users/me`, nunca o UID do
/// Firebase: é ele que aparece como FK em todas as tabelas de negócio.
class Account extends Equatable {
  final String userId;
  final String name;
  final String email;
  final List<String> roles;
  final String? activeGroupId;
  final String? activePlayerId;
  final List<String> groupAdminIds;
  final List<String> groupFinanceiroIds;
  final bool?
      activeGroupIsAdmin; // role na patota ATIVA — atualiza a cada troca
  final bool? activeGroupIsFinanceiro; // idem para financeiro

  const Account({
    required this.userId,
    required this.name,
    required this.email,
    required this.roles,
    this.activeGroupId,
    this.activePlayerId,
    this.groupAdminIds = const [],
    this.groupFinanceiroIds = const [],
    this.activeGroupIsAdmin,
    this.activeGroupIsFinanceiro,
  });

  // ── RBAC helpers ──────────────────────────────────────────────────────────

  bool get isAdmin => roles.any((r) => r.toLowerCase() == 'admin');

  /// GUIDs vindos do backend podem chegar com caixa diferente conforme o endpoint
  /// (`groups/by-admin` devolve `id`, `players/me` devolve `groupId`). Comparar
  /// as strings cruas faz a permissão sumir silenciosamente.
  static String _normalizeId(String? id) =>
      (id ?? '').trim().toLowerCase().replaceAll(RegExp(r'[{}]'), '');

  static bool _containsId(List<String> ids, String groupId) {
    final target = _normalizeId(groupId);
    if (target.isEmpty) return false;
    return ids.any((id) => _normalizeId(id) == target);
  }

  bool _isActiveGroup(String groupId) =>
      _normalizeId(groupId) == _normalizeId(activeGroupId);

  /// Retorna true se o usuário é admin desta patota.
  ///
  /// Para a patota ativa, o flag consultado especificamente no backend é
  /// autoritativo. O array do login é apenas fallback enquanto essa consulta
  /// ainda não terminou. Isso impede que o papel de uma patota vaze para outra.
  bool isGroupAdmin(String groupId) {
    if (_isActiveGroup(groupId) && activeGroupIsAdmin != null) {
      return activeGroupIsAdmin!;
    }
    return _containsId(groupAdminIds, groupId);
  }

  /// Mesma regra do [isGroupAdmin], para o papel de financeiro.
  bool isGroupFinanceiro(String groupId) {
    if (_isActiveGroup(groupId) && activeGroupIsFinanceiro != null) {
      return activeGroupIsFinanceiro!;
    }
    return _containsId(groupFinanceiroIds, groupId);
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
        'activeGroupId': activeGroupId,
        'activePlayerId': activePlayerId,
        'groupAdminIds': groupAdminIds,
        'groupFinanceiroIds': groupFinanceiroIds,
        'activeGroupIsAdmin': activeGroupIsAdmin,
        'activeGroupIsFinanceiro': activeGroupIsFinanceiro,
      };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        userId: json['userId'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        // Limpa contas persistidas por versões antigas: GodMode pertence ao
        // painel web e não deve conceder nem aparecer no aplicativo.
        roles: List<String>.from(json['roles'] as List? ?? [])
            .where((role) => role.trim().toLowerCase() != 'godmode')
            .toList(growable: false),
        activeGroupId: json['activeGroupId'] as String?,
        activePlayerId: json['activePlayerId'] as String?,
        groupAdminIds: List<String>.from(json['groupAdminIds'] as List? ?? []),
        groupFinanceiroIds:
            List<String>.from(json['groupFinanceiroIds'] as List? ?? []),
        activeGroupIsAdmin: json['activeGroupIsAdmin'] as bool?,
        activeGroupIsFinanceiro: json['activeGroupIsFinanceiro'] as bool?,
      );

  Account copyWith({
    String? userId,
    String? name,
    String? email,
    List<String>? roles,
    String? activeGroupId,
    String? activePlayerId,
    bool clearActiveGroupId = false,
    bool clearActivePlayerId = false,
    List<String>? groupAdminIds,
    List<String>? groupFinanceiroIds,
    bool? activeGroupIsAdmin,
    bool? activeGroupIsFinanceiro,
  }) =>
      Account(
        userId: userId ?? this.userId,
        name: name ?? this.name,
        email: email ?? this.email,
        roles: roles ?? this.roles,
        activeGroupId:
            clearActiveGroupId ? null : activeGroupId ?? this.activeGroupId,
        activePlayerId:
            clearActivePlayerId ? null : activePlayerId ?? this.activePlayerId,
        groupAdminIds: groupAdminIds ?? this.groupAdminIds,
        groupFinanceiroIds: groupFinanceiroIds ?? this.groupFinanceiroIds,
        activeGroupIsAdmin: activeGroupIsAdmin ?? this.activeGroupIsAdmin,
        activeGroupIsFinanceiro:
            activeGroupIsFinanceiro ?? this.activeGroupIsFinanceiro,
      );

  @override
  List<Object?> get props => [
        userId,
        name,
        email,
        roles,
        activeGroupId,
        activePlayerId,
        groupAdminIds,
        groupFinanceiroIds,
        activeGroupIsAdmin,
        activeGroupIsFinanceiro,
      ];
}

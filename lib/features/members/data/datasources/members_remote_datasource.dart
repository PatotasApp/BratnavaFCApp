import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../../../core/api/api_constants.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/group_player.dart';

class MembersRemoteDataSource {
  final Dio _dio;
  const MembersRemoteDataSource(this._dio);

  // ── Users ────────────────────────────────────────────────────────────────────

  Future<AppUser> fetchUserById(String id) async {
    final res = await _dio.get(ApiConstants.userById(id));
    final raw = _unwrapMap(res.data);
    return AppUser.fromJson(raw);
  }

  Future<List<AppUser>> fetchUsers() async {
    final res = await _dio.get(
      ApiConstants.users,
      queryParameters: {'pageSize': 200},
    );
    // Response shape: { success, data: { page, pageSize, total, items: [...] } }
    // Fall back to flat list if the API changes shape in the future.
    final raw = _unwrapPagedList(res.data);
    return raw.map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AppUser> updateUser(
    String id, {
    required String firstName,
    required String lastName,
    required String userName,
    required String email,
    String? phone,
    String? birthDate, // ISO-8601, e.g. "1990-05-20"
    bool? isActive,
  }) async {
    final body = <String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'userName': userName,
      'email': email,
      'phone': phone,
      'birthDate': birthDate,
      if (isActive != null) 'isActive': isActive,
    };
    final res = await _dio.put(ApiConstants.userById(id), data: body);
    return AppUser.fromJson(_unwrapMap(res.data));
  }

  // Não há changePassword: a senha vive no Firebase e a API não tem endpoint para ela.
  // A troca acontece pelo fluxo de redefinição por e-mail (sendPasswordResetEmail), que
  // não passa por aqui.

  /// Sem id: o backend resolve o alvo pela identidade do token. Só dá para trocar a
  /// própria foto — admin não altera a de outro usuário.
  Future<void> uploadProfilePhoto(List<int> bytes) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: 'profile.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
    });
    final res = await _dio.post(ApiConstants.usersMePhoto, data: form);
    _throwIfError(res.data);
  }

  /// Sem id, pelo mesmo motivo do upload.
  Future<void> deleteProfilePhoto() async {
    final res = await _dio.delete(ApiConstants.usersMePhoto);
    _throwIfError(res.data);
  }

  Future<AppUser> toggleUserActive(String id, {required bool activate}) async {
    final url = activate
        ? ApiConstants.activateUser(id)
        : ApiConstants.deactivateUser(id);
    final res = await _dio.put(url);
    // Some APIs return the updated user; some return 204. Handle both.
    if (res.data == null || res.statusCode == 204) {
      return fetchUserById(id);
    }
    return AppUser.fromJson(_unwrapMap(res.data));
  }

  // ── Players (group) ───────────────────────────────────────────────────────────

  Future<List<GroupPlayer>> fetchGroupPlayers(String groupId) async {
    final res = await _dio.get(ApiConstants.playersMe);
    final raw = _unwrapList(res.data);
    return raw
        .map((e) => GroupPlayer.fromJson(e as Map<String, dynamic>))
        .where((p) => p.groupId == groupId)
        .toList();
  }

  Future<GroupPlayer> createPlayer(
    String groupId,
    String name,
    bool isGoalkeeper,
    int skillPoints,
    bool isGuest,
  ) async {
    final res = await _dio.post(
      '/api/Players',
      data: {
        'groupId': groupId,
        'name': name,
        'isGoalkeeper': isGoalkeeper,
        'skillPoints': skillPoints,
        'isGuest': isGuest,
      },
    );
    final raw = _unwrapMap(res.data);
    return GroupPlayer.fromJson(raw);
  }

  Future<GroupPlayer> updatePlayer(
    String id,
    String groupId,
    String name,
    bool isGoalkeeper,
    int skillPoints,
    bool isGuest,
  ) async {
    final res = await _dio.put(
      ApiConstants.playerOps(id),
      data: {
        'groupId': groupId,
        'name': name,
        'isGoalkeeper': isGoalkeeper,
        'skillPoints': skillPoints,
        'isGuest': isGuest,
      },
    );
    final raw = _unwrapMap(res.data);
    return GroupPlayer.fromJson(raw);
  }

  Future<void> deletePlayer(String id) async {
    final res = await _dio.delete(ApiConstants.playerOps(id));
    _throwIfError(res.data);
  }

  Future<void> toggleGoalkeeper(String playerId) async {
    final res = await _dio.patch(ApiConstants.playerToggleGoalkeeper(playerId));
    _throwIfError(res.data);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _throwIfError(dynamic data) {
    if (data is Map) {
      final msg = data['error'] as String?;
      if (msg != null && msg.isNotEmpty) throw Exception(msg);
    }
  }

  List<dynamic> _unwrapList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final d = data['data'] ?? data['Data'];
      if (d is List) return d;
    }
    return [];
  }

  /// Handles paginated envelope: { success, data: { items: [...], ... } }
  /// Falls back to _unwrapList for flat responses.
  List<dynamic> _unwrapPagedList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final d = data['data'] ?? data['Data'];
      if (d is List) return d;
      if (d is Map) {
        final items = d['items'] ?? d['Items'];
        if (items is List) return items;
      }
    }
    return [];
  }

  Map<String, dynamic> _unwrapMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
        return data['data'] as Map<String, dynamic>;
      }
      if (data.containsKey('Data') && data['Data'] is Map<String, dynamic>) {
        return data['Data'] as Map<String, dynamic>;
      }
      return data;
    }
    return {};
  }
}

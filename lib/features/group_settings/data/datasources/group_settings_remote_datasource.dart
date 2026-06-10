import 'package:dio/dio.dart';
import '../../../../core/api/api_constants.dart';
import '../../domain/entities/group_settings.dart';

class GroupSettingsRemoteDataSource {
  final Dio _dio;
  const GroupSettingsRemoteDataSource(this._dio);

  // ── Group Settings (icons, payment, defaults) ─────────────────────────────
  // Endpoint: GET/PUT /api/GroupSettings/group/{groupId}

  Future<GroupSettings> fetchGroupSettings(String groupId) async {
    final res = await _dio.get(ApiConstants.groupSettings(groupId));
    return GroupSettings.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> updateGroupSettings(
    String groupId, {
    required int     minPlayers,
    required int     maxPlayers,
    required String? defaultPlaceName,
    required int?    defaultDayOfWeek,
    required String? defaultKickoffTime,
    required int     paymentMode,
    required double? monthlyFee,
    required double? goalkeeperMonthlyFee,
    required String? goalIcon,
    required String? goalkeeperIcon,
    required String? assistIcon,
    required String? ownGoalIcon,
    required String? mvpIcon,
    required String? playerIcon,
    String?          rank1Icon,
    String?          rank2Icon,
    String?          rank3Icon,
    required int     mvpTieRule,
    int?             mvpTieMaxPlayers,
    required bool    showPlayerStats,
    int?             paymentDueDay,
    int?             autoFinalizeMvpHours,
  }) async {
    final body = const GroupSettings().toJson(
      minPlayers:           minPlayers,
      maxPlayers:           maxPlayers,
      defaultPlaceName:     defaultPlaceName,
      defaultDayOfWeek:     defaultDayOfWeek,
      defaultKickoffTime:   defaultKickoffTime,
      paymentMode:          paymentMode,
      monthlyFee:           monthlyFee,
      goalkeeperMonthlyFee: goalkeeperMonthlyFee,
      goalIcon:             goalIcon,
      goalkeeperIcon:       goalkeeperIcon,
      assistIcon:           assistIcon,
      ownGoalIcon:          ownGoalIcon,
      mvpIcon:              mvpIcon,
      playerIcon:           playerIcon,
      rank1Icon:            rank1Icon,
      rank2Icon:            rank2Icon,
      rank3Icon:            rank3Icon,
      mvpTieRule:           mvpTieRule,
      mvpTieMaxPlayers:     mvpTieMaxPlayers,
      showPlayerStats:      showPlayerStats,
      paymentDueDay:        paymentDueDay,
      autoFinalizeMvpHours: autoFinalizeMvpHours,
    );
    final res = await _dio.put(ApiConstants.groupSettings(groupId), data: body);
    _throwIfError(res.data);
  }

  // ── Group Detail (name, admins, financeiros) ──────────────────────────────
  // Endpoint: GET /api/Groups/{groupId}

  Future<GroupDetail> fetchGroupDetail(String groupId) async {
    final res = await _dio.get(ApiConstants.groupById(groupId));
    return GroupDetail.fromJson(res.data as Map<String, dynamic>);
  }

  // ── Admins ────────────────────────────────────────────────────────────────

  Future<void> addAdmin(String groupId, String userId) async {
    final res = await _dio.post(ApiConstants.groupAdmins(groupId), data: {'userId': userId});
    _throwIfError(res.data);
  }

  Future<void> removeAdmin(String groupId, String userId) async {
    final res = await _dio.delete(ApiConstants.groupAdminById(groupId, userId));
    _throwIfError(res.data);
  }

  // ── Financeiros ───────────────────────────────────────────────────────────

  Future<void> addFinanceiro(String groupId, String userId) async {
    final res = await _dio.post(ApiConstants.groupFinanceiros(groupId), data: {'userId': userId});
    _throwIfError(res.data);
  }

  Future<void> removeFinanceiro(String groupId, String userId) async {
    final res = await _dio.delete(ApiConstants.groupFinanceiroById(groupId, userId));
    _throwIfError(res.data);
  }

  // ── Group players (used for admin/financeiro candidate list) ─────────────
  // Reuses GET /api/Groups/{groupId} which already returns the players array.
  // Returns only linked (non-guest) members — candidates for admin/financeiro.

  void _throwIfError(dynamic data) {
    if (data is Map) {
      final msg = data['error'] as String?;
      if (msg != null && msg.isNotEmpty) throw Exception(msg);
    }
  }

  Future<List<GroupMember>> fetchGroupPlayers(String groupId) async {
    final res = await _dio.get(ApiConstants.groupById(groupId));
    dynamic body = res.data;
    if (body is Map) body = body['data'] ?? body;
    final playersRaw = (body as Map<String, dynamic>?)?['players'];
    final list = (playersRaw as List?)?.whereType<Map<String, dynamic>>() ?? [];
    return list
        .where((p) =>
            (p['userId'] as String? ?? '').isNotEmpty && p['isGuest'] != true)
        .map(GroupMember.fromPlayerJson)
        .toList();
  }
}

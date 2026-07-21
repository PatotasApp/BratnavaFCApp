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
    required int minPlayers,
    required int maxPlayers,
    required String? defaultPlaceName,
    required int? defaultDayOfWeek,
    required String? defaultKickoffTime,
    required int paymentMode,
    required double? monthlyFee,
    required double? goalkeeperMonthlyFee,
    required String? goalIcon,
    required String? goalkeeperIcon,
    required String? assistIcon,
    required String? ownGoalIcon,
    required String? mvpIcon,
    required String? playerIcon,
    String? rank1Icon,
    String? rank2Icon,
    String? rank3Icon,
    required int mvpTieRule,
    int? mvpTieMaxPlayers,
    required bool showPlayerStats,
    required bool showStatsGeneralTab,
    required bool showStatsPerMatchTab,
    required bool showStatsClassificationTab,
    int? paymentDueDay,
    int? autoFinalizeMvpHours,
    required bool matchSchedulingEnabled,
    required int matchSchedulingMode,
    int? matchScheduleDayOfWeek,
    String? matchScheduleTime,
    required List<ManualMatchSchedule> manualMatchSchedules,
  }) async {
    final body = const GroupSettings().toJson(
      minPlayers: minPlayers,
      maxPlayers: maxPlayers,
      defaultPlaceName: defaultPlaceName,
      defaultDayOfWeek: defaultDayOfWeek,
      defaultKickoffTime: defaultKickoffTime,
      paymentMode: paymentMode,
      monthlyFee: monthlyFee,
      goalkeeperMonthlyFee: goalkeeperMonthlyFee,
      goalIcon: goalIcon,
      goalkeeperIcon: goalkeeperIcon,
      assistIcon: assistIcon,
      ownGoalIcon: ownGoalIcon,
      mvpIcon: mvpIcon,
      playerIcon: playerIcon,
      rank1Icon: rank1Icon,
      rank2Icon: rank2Icon,
      rank3Icon: rank3Icon,
      mvpTieRule: mvpTieRule,
      mvpTieMaxPlayers: mvpTieMaxPlayers,
      showPlayerStats: showPlayerStats,
      showStatsGeneralTab: showStatsGeneralTab,
      showStatsPerMatchTab: showStatsPerMatchTab,
      showStatsClassificationTab: showStatsClassificationTab,
      paymentDueDay: paymentDueDay,
      autoFinalizeMvpHours: autoFinalizeMvpHours,
      matchSchedulingEnabled: matchSchedulingEnabled,
      matchSchedulingMode: matchSchedulingMode,
      matchScheduleDayOfWeek: matchScheduleDayOfWeek,
      matchScheduleTime: matchScheduleTime,
      manualMatchSchedules: manualMatchSchedules,
    );
    final res = await _dio.put(ApiConstants.groupSettings(groupId), data: body);
    _throwIfError(res.data);
  }

  Future<({String placeName, DateTime playedAt})> fetchMatchBasic(
    String groupId,
    String matchId,
  ) async {
    final res = await _dio.get(ApiConstants.matchById(groupId, matchId));
    final raw = res.data is Map && (res.data as Map).containsKey('data')
        ? (res.data as Map)['data']
        : res.data;
    final data = raw as Map<String, dynamic>;
    return (
      placeName: (data['placeName'] ?? data['PlaceName'] ?? '').toString(),
      playedAt: DateTime.parse(
        (data['playedAt'] ?? data['PlayedAt']).toString(),
      ),
    );
  }

  Future<void> updateMatchBasic(
    String groupId,
    String matchId, {
    required String placeName,
    required DateTime playedAt,
  }) async {
    final res = await _dio.put(
      ApiConstants.matchById(groupId, matchId),
      data: {
        'placeName': placeName,
        'playedAt': playedAt.toIso8601String(),
      },
    );
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
    final res = await _dio
        .post(ApiConstants.groupAdmins(groupId), data: {'userId': userId});
    _throwIfError(res.data);
  }

  Future<void> removeAdmin(String groupId, String userId) async {
    final res = await _dio.delete(ApiConstants.groupAdminById(groupId, userId));
    _throwIfError(res.data);
  }

  // ── Financeiros ───────────────────────────────────────────────────────────

  Future<void> addFinanceiro(String groupId, String userId) async {
    final res = await _dio
        .post(ApiConstants.groupFinanceiros(groupId), data: {'userId': userId});
    _throwIfError(res.data);
  }

  Future<void> removeFinanceiro(String groupId, String userId) async {
    final res =
        await _dio.delete(ApiConstants.groupFinanceiroById(groupId, userId));
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

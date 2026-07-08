import 'package:dio/dio.dart';
import '../../domain/entities/bet_models.dart';

class BetRemoteDataSource {
  final Dio _dio;
  const BetRemoteDataSource(this._dio);

  // ── Endpoints ─────────────────────────────────────────────────────────────

  static String _current(String gid) => '/api/bet/group/$gid/current';
  static String _bettable(String gid) => '/api/Bet/group/$gid/bettable-matches';
  static String _context(String gid, String mid) =>
      '/api/Bet/group/$gid/match/$mid/context';
  static String _bet(String gid, String mid) =>
      '/api/bet/group/$gid/match/$mid';
  static String _leaderboard(String gid) => '/api/bet/group/$gid/leaderboard';
  static String _balance(String gid) => '/api/bet/group/$gid/balance';
  static String _history(String gid) => '/api/bet/group/$gid/history';

  // ── Bettable matches list ─────────────────────────────────────────────────

  Future<List<BettableMatchDto>> fetchBettableMatches(String groupId) async {
    try {
      final res = await _dio.get(_bettable(groupId));
      return _unwrapList(res.data)
          .whereType<Map<String, dynamic>>()
          .map(BettableMatchDto.fromJson)
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      rethrow;
    }
  }

  // ── Context for a specific match ──────────────────────────────────────────

  Future<CurrentMatchBetContext?> fetchContextForMatch(
      String groupId, String matchId) async {
    try {
      final res = await _dio.get(_context(groupId, matchId));
      final data = _unwrapMap(res.data);
      if (data == null) return null;
      return CurrentMatchBetContext.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  // ── Current match + my bet (fallback single-match) ────────────────────────

  Future<CurrentMatchBetContext?> fetchCurrent(String groupId) async {
    try {
      final res = await _dio.get(_current(groupId));
      final data = _unwrapMap(res.data);
      if (data == null) return null;
      return CurrentMatchBetContext.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  // ── Place / update bet ────────────────────────────────────────────────────

  Future<void> placeOrUpdateBet(
      String groupId, String matchId, PlaceMatchBetDto dto) async {
    final res = await _dio.post(_bet(groupId, matchId), data: dto.toJson());
    _throwIfError(res.data);
  }

  // ── Delete my bet ─────────────────────────────────────────────────────────

  Future<void> deleteBet(String groupId, String matchId) async {
    final res = await _dio.delete(_bet(groupId, matchId));
    _throwIfError(res.data);
  }

  // ── Leaderboard ───────────────────────────────────────────────────────────

  Future<List<BetLeaderboardEntry>> fetchLeaderboard(String groupId) async {
    final res = await _dio.get(_leaderboard(groupId));
    final raw = _unwrapList(res.data);
    return raw
        .whereType<Map<String, dynamic>>()
        .map(BetLeaderboardEntry.fromJson)
        .toList();
  }

  // ── Balance ───────────────────────────────────────────────────────────────

  Future<int> fetchBalance(String groupId) async {
    final res = await _dio.get(_balance(groupId));
    final data = _unwrapMap(res.data);
    return (data?['balance'] as num?)?.toInt() ?? 0;
  }

  // ── History ───────────────────────────────────────────────────────────────

  Future<List<MatchBetHistoryDto>> fetchHistory(String groupId) async {
    final res = await _dio.get(
      _history(groupId),
      queryParameters: const {'page': 1, 'pageSize': 200},
    );
    final raw = _unwrapList(res.data);
    return raw
        .whereType<Map<String, dynamic>>()
        .map(MatchBetHistoryDto.fromJson)
        .toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _throwIfError(dynamic data) {
    if (data is Map) {
      final msg = data['error'] as String?;
      if (msg != null && msg.isNotEmpty) throw Exception(msg);
    }
  }

  Map<String, dynamic>? _unwrapMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['data'] is Map<String, dynamic>) {
        return data['data'] as Map<String, dynamic>;
      }
      if (data['Data'] is Map<String, dynamic>) {
        return data['Data'] as Map<String, dynamic>;
      }
      if (data.containsKey('success') || data.containsKey('Success')) {
        return null;
      }
      return data;
    }
    return null;
  }

  List<dynamic> _unwrapList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final inner = data['data'] ?? data['Data'];
      if (inner is List) return inner;
      if (inner is Map) {
        final items = inner['items'] ?? inner['Items'];
        if (items is List) return items;
      }
      final items = data['items'] ?? data['Items'];
      if (items is List) return items;
    }
    return [];
  }
}

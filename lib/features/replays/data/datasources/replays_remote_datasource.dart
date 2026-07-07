import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import '../../domain/entities/replay_clip.dart';

/// Página de replays: itens + total informado pelo backend (para load-more).
typedef ReplayPage = ({List<ReplayClip> items, int total});

class ReplaysRemoteDataSource {
  final Dio _dio;
  const ReplaysRemoteDataSource(this._dio);

  static const int defaultPageSize = 20;

  // ── Endpoint helpers ──────────────────────────────────────────────────────

  static String _all(String gid) =>
      '/api/matches/group/$gid/replays/all';
  static String _myLikes(String gid) =>
      '/api/matches/group/$gid/replays/my-likes';
  static String _myFavorites(String gid) =>
      '/api/matches/group/$gid/replays/my-favorites';
  static String _like(String gid, String cid) =>
      '/api/matches/group/$gid/replays/$cid/like';
  static String _favorite(String gid, String cid) =>
      '/api/matches/group/$gid/replays/$cid/favorite';
  static String _stream(String gid, String cid) =>
      '/api/matches/group/$gid/replays/$cid/stream';
  static String _delete(String gid, String cid) =>
      '/api/matches/group/$gid/replays/$cid';

  // ── Queries (paginadas) ───────────────────────────────────────────────────

  Future<ReplayPage> fetchAll(String groupId,
          {int page = 1, int pageSize = defaultPageSize}) =>
      _fetchPage(_all(groupId), page: page, pageSize: pageSize);

  Future<ReplayPage> fetchMyLikes(String groupId,
          {int page = 1, int pageSize = defaultPageSize}) =>
      _fetchPage(_myLikes(groupId), page: page, pageSize: pageSize);

  Future<ReplayPage> fetchMyFavorites(String groupId,
          {int page = 1, int pageSize = defaultPageSize}) =>
      _fetchPage(_myFavorites(groupId), page: page, pageSize: pageSize);

  Future<ReplayPage> _fetchPage(String path,
      {required int page, required int pageSize}) async {
    final res = await _dio.get(path, queryParameters: {
      'page': page,
      'pageSize': pageSize,
    });
    final items = unwrapList(res.data)
        .map((e) => ReplayClip.fromJson(e as Map<String, dynamic>))
        .toList();
    final total = extractTotal(res.data) ?? items.length;
    return (items: items, total: total);
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  /// Returns the new like state and count.
  Future<({bool isLiked, int likeCount})> toggleLike(
      String groupId, String clipId) async {
    final res = await _dio.post(_like(groupId, clipId));
    final data = _unwrapMap(res.data);
    return (
      isLiked:   data['isLiked']   as bool? ?? false,
      likeCount: data['likeCount'] as int?  ?? 0,
    );
  }

  /// Returns the new favorite state.
  Future<bool> toggleFavorite(String groupId, String clipId) async {
    final res = await _dio.post(_favorite(groupId, clipId));
    final data = _unwrapMap(res.data);
    return data['isFavorited'] as bool? ?? false;
  }

  Future<void> deleteClip(String groupId, String clipId) async {
    final res = await _dio.delete(_delete(groupId, clipId));
    _throwIfError(res.data);
  }

  /// Returns the relative stream path (caller appends base URL + token).
  String streamPath(String groupId, String clipId) =>
      _stream(groupId, clipId);

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _throwIfError(dynamic data) {
    if (data is Map) {
      final msg = data['error'] as String?;
      if (msg != null && msg.isNotEmpty) throw Exception(msg);
    }
  }

  /// Desembrulha a lista de itens tolerando três formatos de resposta:
  ///  - array cru:                      `[ {...}, {...} ]`
  ///  - envelope ApiResponse:           `{ data: [ {...} ] }`
  ///  - envelope + PagedResultDto:       `{ data: { items: [ {...} ] } }`
  @visibleForTesting
  static List<dynamic> unwrapList(dynamic data) {
    dynamic node = data;
    if (node is Map) node = node['data'] ?? node['Data'] ?? node;   // ApiResponse
    if (node is Map) node = node['items'] ?? node['Items'] ?? node; // PagedResultDto
    return node is List ? node : const [];
  }

  /// Extrai `total` do PagedResultDto quando presente.
  @visibleForTesting
  static int? extractTotal(dynamic data) {
    dynamic node = data;
    if (node is Map) node = node['data'] ?? node['Data'] ?? node;
    if (node is Map) return node['total'] as int? ?? node['Total'] as int?;
    return null;
  }

  Map<String, dynamic> _unwrapMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      final inner = data['data'] ?? data['Data'];
      if (inner is Map<String, dynamic>) return inner;
      return data;
    }
    return const {};
  }
}

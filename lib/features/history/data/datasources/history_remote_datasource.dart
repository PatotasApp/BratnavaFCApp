import 'package:dio/dio.dart';
import '../../../../core/api/api_constants.dart';
import '../../../../core/api/api_response.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/history_match.dart';
import '../../domain/entities/match_details.dart';
import '../../../replays/domain/entities/replay_clip.dart';

class HistoryRemoteDataSource {
  final Dio _dio;

  const HistoryRemoteDataSource(this._dio);

  Future<PagedHistoryMatches> fetchHistoryPage(
    String groupId, {
    required int page,
    required int pageSize,
    String? playerId,
  }) async {
    try {
      final skip = (page - 1) * pageSize;
      final res = await _dio.get(
        ApiConstants.matchHistory(groupId),
        queryParameters: {
          'take': pageSize,
          'skip': skip,
          'page': page,
          'pageSize': pageSize,
          if (playerId != null) 'playerId': playerId,
        },
      );
      final items = unwrapList(res.data)
          .whereType<Map<String, dynamic>>()
          .map((e) => HistoryMatch.fromJson(e, groupId: groupId))
          .toList();

      return PagedHistoryMatches(
        items: items,
        total: _extractTotal(res.data) ?? items.length,
        page: _extractPage(res.data) ?? page,
        pageSize: _extractPageSize(res.data) ?? pageSize,
      );
    } on DioException catch (e) {
      throw ServerException(extractDioError(e));
    }
  }

  Future<List<HistoryMatch>> fetchHistory(
    String groupId, {
    int take = 400,
  }) async {
    try {
      final historyRes = await _dio.get(
        ApiConstants.matchHistory(groupId),
        queryParameters: {'take': take, 'page': 1, 'pageSize': take},
      );
      final list = unwrapList(historyRes.data)
          .map((e) => HistoryMatch.fromJson(
                e as Map<String, dynamic>,
                groupId: groupId,
              ))
          .toList();

      // Coloca a partida em aberto no topo, se ainda não estiver no histórico.
      // Usa `upcoming` (headers) em vez de `/current`, que traz o detalhe
      // completo da partida só para lermos o id.
      try {
        final currentRes =
            await _dio.get(ApiConstants.upcomingMatches(groupId));
        final headers = unwrapList(currentRes.data);
        if (headers.isNotEmpty) {
          final current = headers.first as Map<String, dynamic>;
          final activeId =
              (current['matchId'] ?? current['id'] ?? '').toString();
          final alreadyPresent = list.any((m) => m.id == activeId);
          if (!alreadyPresent && activeId.isNotEmpty) {
            list.insert(0, HistoryMatch.fromJson(current, groupId: groupId));
          }
        }
      } catch (_) {
        // Nenhuma partida em aberto — ignora.
      }

      return list;
    } on DioException catch (e) {
      throw ServerException(extractDioError(e));
    }
  }

  Future<MatchDetails> fetchMatchDetails(
    String groupId,
    String matchId,
  ) async {
    try {
      final res = await _dio.get(ApiConstants.matchDetails(groupId, matchId));
      final data = unwrapMap(res.data);
      if (data == null) throw const ServerException('Partida não encontrada');
      return MatchDetails.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const ServerException('Partida não encontrada');
      }
      throw ServerException(extractDioError(e));
    }
  }

  Future<List<ReplayClip>> fetchMatchReplays(
    String groupId,
    String matchId,
  ) async {
    try {
      final res = await _dio.get(ApiConstants.matchReplays(groupId, matchId));
      final d = unwrapList(res.data);
      return d
          .whereType<Map<String, dynamic>>()
          .map(ReplayClip.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ServerException(extractDioError(e));
    }
  }

  /// Returns the set of matchIds where the given player participated.
  /// Queries the last two calendar years for broad coverage.
  Future<Set<String>> fetchMyMatchIds(
    String groupId,
    String playerId,
  ) async {
    final ids = <String>{};
    final years = [DateTime.now().year, DateTime.now().year - 1];
    for (final year in years) {
      try {
        final res = await _dio.get(
          ApiConstants.playerHistory(groupId),
          queryParameters: {'playerId': playerId, 'year': year},
        );
        for (final e in unwrapList(res.data)) {
          if (e is! Map) continue;
          final id = (e['matchId'] ?? e['id'])?.toString();
          if (id != null && id.isNotEmpty) ids.add(id);
        }
      } catch (_) {
        // Year may have no data — silently skip
      }
    }
    return ids;
  }

  Future<String?> generateMatchCard(
    String groupId,
    Map<String, dynamic> dto,
  ) async {
    try {
      final res = await _dio.post(ApiConstants.matchCard(groupId), data: dto);
      final d = unwrapMap(res.data);
      if (d == null) return null;
      return d['image'] as String? ?? d['base64'] as String?;
    } on DioException catch (e) {
      throw ServerException(extractDioError(e));
    }
  }

  int? _extractTotal(dynamic data) {
    if (data is! Map) return null;
    final node = data['data'] ?? data['Data'] ?? data;
    if (node is! Map) return null;
    final total = node['total'] ??
        node['Total'] ??
        node['totalCount'] ??
        node['TotalCount'];
    return (total as num?)?.toInt();
  }

  int? _extractPage(dynamic data) {
    if (data is! Map) return null;
    final node = data['data'] ?? data['Data'] ?? data;
    if (node is! Map) return null;
    final value = node['page'] ?? node['Page'];
    return (value as num?)?.toInt();
  }

  int? _extractPageSize(dynamic data) {
    if (data is! Map) return null;
    final node = data['data'] ?? data['Data'] ?? data;
    if (node is! Map) return null;
    final value = node['pageSize'] ?? node['PageSize'];
    return (value as num?)?.toInt();
  }
}

class PagedHistoryMatches {
  final List<HistoryMatch> items;
  final int total;
  final int page;
  final int pageSize;

  const PagedHistoryMatches({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });
}

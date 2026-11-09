import 'package:dio/dio.dart';
import '../domain/discovery_models.dart';

class DiscoveryDataSource {
  const DiscoveryDataSource(this._dio);
  final Dio _dio;
  dynamic _data(Response r) => r.data is Map ? (r.data as Map)['data'] : null;
  Future<List<DiscoveryGroupItem>> groups(String q) async {
    final r = await _dio.get(
      '/api/discovery/groups',
      queryParameters: {'q': q, 'pageSize': 30},
    );
    final d = _data(r) as Map;
    return ((d['items'] as List?) ?? [])
        .map(
          (e) =>
              DiscoveryGroupItem.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<List<DiscoveryPlayerItem>> players(String q) async {
    final r = await _dio.get(
      '/api/discovery/players',
      queryParameters: {'q': q, 'pageSize': 30},
    );
    final d = _data(r) as Map;
    return ((d['items'] as List?) ?? [])
        .map(
          (e) =>
              DiscoveryPlayerItem.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<DiscoveryGroupProfile> group(String id) async {
    final r = await _dio.get('/api/discovery/groups/$id');
    return DiscoveryGroupProfile.fromJson(
      Map<String, dynamic>.from(_data(r) as Map),
    );
  }

  Future<void> apply(String groupId, String openingId) => _dio.post(
        '/api/discovery/groups/$groupId/applications',
        data: {'openingId': openingId},
      );
  Future<void> createOpening(
    String groupId,
    String matchId,
    int slots,
    int position,
  ) =>
      _dio.post(
        '/api/discovery/groups/$groupId/matches/$matchId/openings',
        data: {'slots': slots, 'position': position},
      );
  Future<void> deleteOpening(String groupId, String openingId) =>
      _dio.delete('/api/discovery/groups/$groupId/openings/$openingId');
  Future<List<MatchApplication>> applications(String groupId) async {
    final r = await _dio.get('/api/discovery/groups/$groupId/applications');
    return ((_data(r) as List?) ?? [])
        .map(
          (e) => MatchApplication.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<List<GuestCandidate>> guestCandidates(
    String groupId,
    String userId,
  ) async {
    final r = await _dio.get(
      '/api/discovery/groups/$groupId/guest-candidates/$userId',
    );
    return ((_data(r) as List?) ?? [])
        .map(
          (e) => GuestCandidate.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> approve(String groupId, String applicationId, String? guestId) =>
      _dio.patch(
        '/api/discovery/groups/$groupId/applications/$applicationId/approve',
        data: {'guestPlayerId': guestId},
      );
  Future<void> reject(String groupId, String applicationId) => _dio.patch(
        '/api/discovery/groups/$groupId/applications/$applicationId/reject',
      );
  Future<List<MatchApplication>> myApplications() async {
    final r = await _dio.get('/api/discovery/applications/mine');
    return ((_data(r) as List?) ?? [])
        .map(
          (e) => MatchApplication.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> acceptInvitation(String applicationId) =>
      _dio.patch('/api/discovery/applications/$applicationId/accept');
  Future<void> rejectInvitation(String applicationId) =>
      _dio.patch('/api/discovery/applications/$applicationId/reject');
  Future<void> invite(String groupId, String matchId, String userId) =>
      _dio.post(
        '/api/discovery/groups/$groupId/invitations',
        data: {
          'matchId': matchId,
          'userId': userId,
          'guestPlayerId': null,
        },
      );
  Future<void> updateProfile(
    String groupId, {
    required bool isPublic,
    required bool accepting,
    required bool showMembers,
    String? description,
    String? city,
  }) =>
      _dio.put(
        '/api/discovery/groups/$groupId/profile',
        data: {
          'isPublic': isPublic,
          'isAcceptingPlayers': accepting,
          'showMembers': showMembers,
          'description': description,
          'city': city,
        },
      );
  Future<String> regenerateCode(String groupId) async {
    final r = await _dio.post('/api/discovery/groups/$groupId/code/regenerate');
    return _data(r) as String;
  }
}

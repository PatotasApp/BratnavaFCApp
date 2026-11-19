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

  Future<void> apply(String groupId, String matchId, {String? message}) =>
      _dio.post(
        '/api/discovery/groups/$groupId/applications',
        data: {'matchId': matchId, 'message': message},
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
    final r = await _dio.get(
      '/api/discovery/groups/$groupId/applications',
      queryParameters: {'history': true},
    );
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

  Future<void> approve(String groupId, String applicationId, String? guestId,
          {String? reason}) =>
      _dio.patch(
        '/api/discovery/groups/$groupId/applications/$applicationId/approve',
        data: {'guestPlayerId': guestId, 'reason': reason},
      );
  Future<void> reject(String groupId, String applicationId, {String? reason}) =>
      _dio.patch(
        '/api/discovery/groups/$groupId/applications/$applicationId/reject',
        data: {'reason': reason},
      );
  Future<List<MatchApplication>> myApplications() async {
    final r = await _dio.get(
      '/api/discovery/applications/mine',
      queryParameters: {'history': true},
    );
    return ((_data(r) as List?) ?? [])
        .map(
          (e) => MatchApplication.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<GuestMatch> guestMatch(String matchId) async {
    final r = await _dio.get('/api/discovery/guest-matches/$matchId');
    return GuestMatch.fromJson(Map<String, dynamic>.from(_data(r) as Map));
  }

  Future<GuestMatch> setGuestAttendance(String matchId, bool going) async {
    final r = await _dio.patch(
      '/api/discovery/guest-matches/$matchId/attendance',
      data: {'going': going},
    );
    return GuestMatch.fromJson(Map<String, dynamic>.from(_data(r) as Map));
  }

  Future<void> acceptInvitation(String applicationId) =>
      _dio.patch('/api/discovery/applications/$applicationId/accept');
  Future<void> rejectInvitation(String applicationId) =>
      _dio.patch('/api/discovery/applications/$applicationId/reject');
  Future<void> invite(String groupId, String matchId, String userId,
          {String? openingId, String? message}) =>
      _dio.post(
        '/api/discovery/groups/$groupId/invitations',
        data: {
          'matchId': matchId,
          'userId': userId,
          'guestPlayerId': null,
          'openingId': openingId,
          'message': message,
        },
      );
  Future<void> updateProfile(
    String groupId, {
    required bool isPublic,
    required bool accepting,
    required bool showMembers,
    bool showGoalsToGuests = false,
    String? description,
    String? city,
  }) =>
      _dio.put(
        '/api/discovery/groups/$groupId/profile',
        data: {
          'isPublic': isPublic,
          'isAcceptingPlayers': accepting,
          'showMembers': showMembers,
          'showGoalsToGuests': showGoalsToGuests,
          'description': description,
          'city': city,
        },
      );
  Future<String> regenerateCode(String groupId) async {
    final r = await _dio.post('/api/discovery/groups/$groupId/code/regenerate');
    return _data(r) as String;
  }
}

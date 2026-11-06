import 'package:dio/dio.dart';

import '../../../core/share/share_links.dart';

/// Resposta de `/api/public/share/{kind}/{id}`.
class ShareResolution {
  final String kind;
  final String id;

  /// `member`, `login_required` ou `not_member`.
  final String access;
  final String? groupId;
  final String? groupName;
  final String? groupLogoUrl;
  final String? matchStatus;
  final String? pollType;

  const ShareResolution({
    required this.kind,
    required this.id,
    required this.access,
    this.groupId,
    this.groupName,
    this.groupLogoUrl,
    this.matchStatus,
    this.pollType,
  });

  bool get isMember => access == 'member';

  factory ShareResolution.fromJson(Map<String, dynamic> json) =>
      ShareResolution(
        kind: json['kind'] as String? ?? '',
        id: json['id'] as String? ?? '',
        access: json['access'] as String? ?? 'not_member',
        groupId: json['groupId'] as String?,
        groupName: json['groupName'] as String?,
        groupLogoUrl: json['groupLogoUrl'] as String?,
        matchStatus: json['matchStatus'] as String?,
        pollType: json['pollType'] as String?,
      );
}

/// Vitrine da patota (`/api/public/groups/{id}`).
class PublicGroup {
  final String groupId;
  final String name;
  final String? logoUrl;
  final int sinceYear;
  final int membersCount;
  final int matchesPlayed;
  final int goalsScored;
  final int? dayOfWeek;
  final String? kickoffTime;
  final String? placeName;

  const PublicGroup({
    required this.groupId,
    required this.name,
    this.logoUrl,
    required this.sinceYear,
    required this.membersCount,
    required this.matchesPlayed,
    required this.goalsScored,
    this.dayOfWeek,
    this.kickoffTime,
    this.placeName,
  });

  factory PublicGroup.fromJson(Map<String, dynamic> json) => PublicGroup(
        groupId: json['groupId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        logoUrl: json['logoUrl'] as String?,
        sinceYear: (json['sinceYear'] as num?)?.toInt() ?? 0,
        membersCount: (json['membersCount'] as num?)?.toInt() ?? 0,
        matchesPlayed: (json['matchesPlayed'] as num?)?.toInt() ?? 0,
        goalsScored: (json['goalsScored'] as num?)?.toInt() ?? 0,
        dayOfWeek: (json['dayOfWeek'] as num?)?.toInt(),
        kickoffTime: json['kickoffTime'] as String?,
        placeName: json['placeName'] as String?,
      );

  static const _days = [
    'Todo domingo',
    'Toda segunda',
    'Toda terça',
    'Toda quarta',
    'Toda quinta',
    'Toda sexta',
    'Todo sábado',
  ];

  /// "Toda quinta, 20h" (igual ao site).
  String? get schedule {
    final day = dayOfWeek != null && dayOfWeek! >= 0 && dayOfWeek! < 7
        ? _days[dayOfWeek!]
        : null;
    final time = kickoffTime == null
        ? null
        : kickoffTime!
            .replaceFirstMapped(RegExp(r'^(\d{2}):00$'), (m) => '${m[1]}h')
            .replaceFirst(':', 'h');
    if (day != null && time != null) return '$day, $time';
    return day ?? (time != null ? 'Às $time' : null);
  }
}

class PublicGroupResponse {
  final bool enabled;
  final bool isMember;
  final PublicGroup? group;

  const PublicGroupResponse(
      {required this.enabled, required this.isMember, this.group});

  factory PublicGroupResponse.fromJson(Map<String, dynamic> json) =>
      PublicGroupResponse(
        enabled: json['enabled'] as bool? ?? false,
        isMember: json['isMember'] as bool? ?? false,
        group: json['group'] is Map<String, dynamic>
            ? PublicGroup.fromJson(json['group'] as Map<String, dynamic>)
            : null,
      );
}

class ShareApi {
  final Dio _dio;
  const ShareApi(this._dio);

  Map<String, dynamic> _data(Response res) {
    final body = res.data;
    final data = body is Map<String, dynamic> ? body['data'] : null;
    return data is Map<String, dynamic> ? data : const {};
  }

  /// Null quando o link não existe (404).
  Future<ShareResolution?> resolve(ShareKind kind, String id) async {
    try {
      final res = await _dio.get('/api/public/share/${kind.apiKind}/$id');
      return ShareResolution.fromJson(_data(res));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<PublicGroupResponse?> group(String groupId) async {
    try {
      final res = await _dio.get('/api/public/groups/$groupId');
      return PublicGroupResponse.fromJson(_data(res));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}

/// Rota interna do conteúdo para quem é integrante.
String internalRouteFor(ShareResolution r) {
  switch (r.kind) {
    case 'match':
    case 'mvp':
      return r.matchStatus == 'Finalized'
          ? '/app/history/${r.groupId}/${r.id}'
          : '/app/matches?matchId=${r.id}';
    case 'championship':
      return '/app/championships/${r.id}';
    case 'poll':
      return r.pollType == 'event'
          ? '/app/polls/events?pollId=${r.id}'
          : '/app/polls/votes?pollId=${r.id}';
    default:
      return '/app';
  }
}

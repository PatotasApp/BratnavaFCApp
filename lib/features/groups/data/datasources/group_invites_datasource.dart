import 'package:dio/dio.dart';
import '../../../../core/api/api_constants.dart';
import '../../domain/entities/group_invite.dart';

class GroupInvitesDatasource {
  final Dio _dio;
  const GroupInvitesDatasource(this._dio);

  dynamic _unwrap(dynamic data) => (data is Map)
      ? (data.containsKey('data')
          ? data['data']
          : data.containsKey('Data')
              ? data['Data']
              : data)
      : data;

  Future<List<GroupInvite>> getMyInvites() async {
    final res = await _dio.get(ApiConstants.myGroupInvites);
    final d = _unwrap(res.data);
    final list = d is List ? d : [];
    return list
        .map((e) => GroupInvite.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> getMyInviteCount() async {
    try {
      final res = await _dio.get(ApiConstants.myGroupInvitesCount);
      final d = _unwrap(res.data);
      if (d is int) return d;
      if (d is Map) return (d['count'] ?? d['total'] ?? 0) as int;
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> acceptInvite(String inviteId) async {
    final res = await _dio.patch(ApiConstants.groupInviteAccept(inviteId));
    _throwIfError(res.data);
  }

  Future<void> rejectInvite(String inviteId) async {
    final res = await _dio.patch(ApiConstants.groupInviteReject(inviteId));
    _throwIfError(res.data);
  }

  void _throwIfError(dynamic data) {
    if (data is Map) {
      final msg = data['error'] as String?;
      if (msg != null && msg.isNotEmpty) throw Exception(msg);
    }
  }
}

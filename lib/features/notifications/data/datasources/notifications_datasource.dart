import 'package:dio/dio.dart';
import '../../../../core/api/api_constants.dart';
import '../../domain/entities/app_notification.dart';

class NotificationsDatasource {
  final Dio _dio;
  const NotificationsDatasource(this._dio);

  dynamic _unwrap(dynamic data) {
    if (data is Map) {
      if (data.containsKey('data')) return data['data'];
      if (data.containsKey('Data')) return data['Data'];
    }
    return data;
  }

  Future<List<AppNotification>> getMyNotifications() async {
    final res = await _dio.get(ApiConstants.myNotifications);
    final d = _unwrap(res.data);
    final list = d is List ? d : <dynamic>[];
    return list
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> getUnreadCount() async {
    try {
      final res = await _dio.get(ApiConstants.myNotificationsUnreadCount);
      final d = _unwrap(res.data);
      if (d is int) return d;
      if (d is Map) {
        return (d['count'] ?? d['unreadCount'] ?? d['total'] ?? 0) as int;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markRead(String notificationId) async {
    final res =
        await _dio.patch(ApiConstants.notificationMarkRead(notificationId));
    _throwIfError(res.data);
  }

  Future<void> markAllRead() async {
    final res = await _dio.patch(ApiConstants.notificationsMarkAllRead);
    _throwIfError(res.data);
  }

  void _throwIfError(dynamic data) {
    if (data is Map) {
      final msg = data['error'] as String?;
      if (msg != null && msg.isNotEmpty) throw Exception(msg);
    }
  }
}

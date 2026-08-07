import 'dart:convert';
import 'package:equatable/equatable.dart';

class AppNotification extends Equatable {
  final String id;
  final String type; // e.g. 'match_invite_reminder', 'poll_closed'
  final String title;
  final String body;
  final bool isRead;
  final String createdAt; // ISO-8601
  final String? actionUrl; // optional explicit deep-link
  final Map<String, dynamic>?
      dataJson; // IDs associados: matchId, pollId, groupId…

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.actionUrl,
    this.dataJson,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic>? dataMap;
    final rawData = j['dataJson'];
    if (rawData is Map<String, dynamic>) {
      dataMap = rawData;
    } else if (rawData is String && rawData.isNotEmpty) {
      try {
        dataMap = jsonDecode(rawData) as Map<String, dynamic>?;
      } catch (_) {}
    }

    return AppNotification(
      id: (j['id'] ?? j['notificationId'] ?? '') as String,
      type: (j['type'] ?? '') as String,
      title: (j['title'] ?? '') as String,
      body: (j['body'] ?? j['message'] ?? '') as String,
      isRead: (j['isRead'] ?? j['read'] ?? false) as bool,
      createdAt: (j['createdAt'] ?? j['sentAt'] ?? '') as String,
      actionUrl: j['actionUrl'] as String?,
      dataJson: dataMap,
    );
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        actionUrl: actionUrl,
        dataJson: dataJson,
      );

  @override
  List<Object?> get props =>
      [id, type, title, body, isRead, createdAt, actionUrl, dataJson];
}

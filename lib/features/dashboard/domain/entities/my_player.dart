import 'package:equatable/equatable.dart';

class MyPlayer extends Equatable {
  final String playerId;
  final String? userId;
  final String groupId;
  final String groupName;
  final String playerName;
  final bool isGoalkeeper;
  final int skillPoints;
  final bool isGuest;
  final String? photoUrl;
  final String? groupLogoUrl;

  const MyPlayer({
    required this.playerId,
    this.userId,
    required this.groupId,
    required this.groupName,
    required this.playerName,
    required this.isGoalkeeper,
    required this.skillPoints,
    required this.isGuest,
    this.photoUrl,
    this.groupLogoUrl,
  });

  factory MyPlayer.fromJson(Map<String, dynamic> j) => MyPlayer(
        playerId: j['playerId'] as String? ?? '',
        userId: j['userId'] as String? ?? j['UserId'] as String?,
        groupId: j['groupId'] as String? ?? '',
        groupName: j['groupName'] as String? ?? '',
        playerName: j['playerName'] as String? ?? '',
        isGoalkeeper: j['isGoalkeeper'] as bool? ?? false,
        skillPoints: j['skillPoints'] as int? ?? 0,
        isGuest: j['isGuest'] as bool? ?? false,
        photoUrl: j['photoUrl'] as String?,
        groupLogoUrl: j['groupLogoUrl'] as String?,
      );

  @override
  List<Object?> get props => [
        playerId,
        userId,
        groupId,
        groupName,
        playerName,
        isGoalkeeper,
        skillPoints,
        isGuest,
        photoUrl,
        groupLogoUrl,
      ];
}

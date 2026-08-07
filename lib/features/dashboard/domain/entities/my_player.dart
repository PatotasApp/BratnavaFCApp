import 'package:equatable/equatable.dart';

class MyPlayer extends Equatable {
  final String playerId;
  final String groupId;
  final String groupName;
  final String playerName;
  final bool isGoalkeeper;
  final int skillPoints;
  final bool isGuest;

  const MyPlayer({
    required this.playerId,
    required this.groupId,
    required this.groupName,
    required this.playerName,
    required this.isGoalkeeper,
    required this.skillPoints,
    required this.isGuest,
  });

  factory MyPlayer.fromJson(Map<String, dynamic> j) => MyPlayer(
        playerId: j['playerId'] as String? ?? '',
        groupId: j['groupId'] as String? ?? '',
        groupName: j['groupName'] as String? ?? '',
        playerName: j['playerName'] as String? ?? '',
        isGoalkeeper: j['isGoalkeeper'] as bool? ?? false,
        skillPoints: j['skillPoints'] as int? ?? 0,
        isGuest: j['isGuest'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [
        playerId,
        groupId,
        groupName,
        playerName,
        isGoalkeeper,
        skillPoints,
        isGuest
      ];
}

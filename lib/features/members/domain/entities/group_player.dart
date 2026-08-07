import 'package:equatable/equatable.dart';

class GroupPlayer extends Equatable {
  final String id;
  final String groupId;
  final String name;
  final bool isGoalkeeper;
  final int skillPoints;
  final bool isGuest;
  final bool isActive;
  final String? userId;

  const GroupPlayer({
    required this.id,
    required this.groupId,
    required this.name,
    required this.isGoalkeeper,
    required this.skillPoints,
    required this.isGuest,
    required this.isActive,
    this.userId,
  });

  factory GroupPlayer.fromJson(Map<String, dynamic> j) => GroupPlayer(
        id: j['id'] as String? ?? j['playerId'] as String? ?? '',
        groupId: j['groupId'] as String? ?? '',
        name: j['name'] as String? ?? j['playerName'] as String? ?? '',
        isGoalkeeper: j['isGoalkeeper'] as bool? ?? false,
        skillPoints: j['skillPoints'] as int? ?? 0,
        isGuest: j['isGuest'] as bool? ?? false,
        isActive: j['isActive'] as bool? ?? true,
        userId: j['userId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'name': name,
        'isGoalkeeper': isGoalkeeper,
        'skillPoints': skillPoints,
        'isGuest': isGuest,
      };

  GroupPlayer copyWith({
    String? id,
    String? groupId,
    String? name,
    bool? isGoalkeeper,
    int? skillPoints,
    bool? isGuest,
    bool? isActive,
    String? userId,
  }) =>
      GroupPlayer(
        id: id ?? this.id,
        groupId: groupId ?? this.groupId,
        name: name ?? this.name,
        isGoalkeeper: isGoalkeeper ?? this.isGoalkeeper,
        skillPoints: skillPoints ?? this.skillPoints,
        isGuest: isGuest ?? this.isGuest,
        isActive: isActive ?? this.isActive,
        userId: userId ?? this.userId,
      );

  @override
  List<Object?> get props => [
        id,
        groupId,
        name,
        isGoalkeeper,
        skillPoints,
        isGuest,
        isActive,
        userId,
      ];
}

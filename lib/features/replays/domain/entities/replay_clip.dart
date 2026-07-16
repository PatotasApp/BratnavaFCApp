import 'package:equatable/equatable.dart';

class ReplayClip extends Equatable {
  // The API returns `id` for the clip identifier.
  final String clipId;
  final String matchId;
  final String matchDate;
  final String matchPlace;
  // Pre-signed direct video URL (Cloudflare R2 or similar).
  final String? videoUrl;
  final String? objectKey;
  final String? eventType; // e.g. "Gol"
  final String? scorerName;
  final String? assistName;
  final String? teamName;
  final int? minute;
  final bool isLiked;
  final bool isFavorited;
  final int likeCount;
  final String createdAt;

  const ReplayClip({
    required this.clipId,
    required this.matchId,
    required this.matchDate,
    required this.matchPlace,
    this.videoUrl,
    this.objectKey,
    this.eventType,
    this.scorerName,
    this.assistName,
    this.teamName,
    this.minute,
    required this.isLiked,
    required this.isFavorited,
    required this.likeCount,
    required this.createdAt,
  });

  factory ReplayClip.fromJson(Map<String, dynamic> j) => ReplayClip(
        // Support both `id` (new API) and `clipId` (legacy)
        clipId: (j['clipId'] ?? j['id'] ?? '') as String,
        matchId: (j['matchId'] ?? '') as String,
        matchDate: (j['matchDate'] ?? j['recordedAt'] ?? '') as String,
        matchPlace: (j['matchPlace'] ?? '') as String,
        videoUrl: j['videoUrl'] as String?,
        objectKey: j['objectKey'] as String?,
        eventType: j['eventType'] as String?,
        scorerName: j['scorerName'] as String?,
        assistName: j['assistName'] as String?,
        teamName: j['teamName'] as String?,
        minute: j['minute'] as int?,
        // Support both `isLiked` (legacy) and `isLikedByMe` (new API)
        isLiked: (j['isLiked'] ?? j['isLikedByMe'] ?? false) as bool,
        isFavorited:
            (j['isFavorited'] ?? j['isFavoritedByMe'] ?? false) as bool,
        likeCount: (j['likeCount'] ?? 0) as int,
        createdAt: (j['createdAt'] ?? j['recordedAt'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'clipId': clipId,
        'matchId': matchId,
        'matchDate': matchDate,
        'matchPlace': matchPlace,
        if (videoUrl != null) 'videoUrl': videoUrl,
        if (objectKey != null) 'objectKey': objectKey,
        if (eventType != null) 'eventType': eventType,
        if (scorerName != null) 'scorerName': scorerName,
        if (assistName != null) 'assistName': assistName,
        if (teamName != null) 'teamName': teamName,
        if (minute != null) 'minute': minute,
        'isLiked': isLiked,
        'isFavorited': isFavorited,
        'likeCount': likeCount,
        'createdAt': createdAt,
      };

  ReplayClip copyWith({
    String? clipId,
    String? matchId,
    String? matchDate,
    String? matchPlace,
    String? videoUrl,
    String? objectKey,
    String? eventType,
    String? scorerName,
    String? assistName,
    String? teamName,
    int? minute,
    bool? isLiked,
    bool? isFavorited,
    int? likeCount,
    String? createdAt,
  }) =>
      ReplayClip(
        clipId: clipId ?? this.clipId,
        matchId: matchId ?? this.matchId,
        matchDate: matchDate ?? this.matchDate,
        matchPlace: matchPlace ?? this.matchPlace,
        videoUrl: videoUrl ?? this.videoUrl,
        objectKey: objectKey ?? this.objectKey,
        eventType: eventType ?? this.eventType,
        scorerName: scorerName ?? this.scorerName,
        assistName: assistName ?? this.assistName,
        teamName: teamName ?? this.teamName,
        minute: minute ?? this.minute,
        isLiked: isLiked ?? this.isLiked,
        isFavorited: isFavorited ?? this.isFavorited,
        likeCount: likeCount ?? this.likeCount,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  List<Object?> get props => [
        clipId,
        matchId,
        matchDate,
        matchPlace,
        videoUrl,
        objectKey,
        eventType,
        scorerName,
        assistName,
        teamName,
        minute,
        isLiked,
        isFavorited,
        likeCount,
        createdAt,
      ];
}

class ReplayLiker extends Equatable {
  final String userId;
  final String userName;
  final String likedAt;

  const ReplayLiker({
    required this.userId,
    required this.userName,
    required this.likedAt,
  });

  factory ReplayLiker.fromJson(Map<String, dynamic> j) => ReplayLiker(
        userId: (j['userId'] ?? j['UserId'] ?? '').toString(),
        userName: (j['userName'] ?? j['UserName'] ?? '').toString(),
        likedAt: (j['likedAt'] ?? j['LikedAt'] ?? '').toString(),
      );

  @override
  List<Object?> get props => [userId, userName, likedAt];
}

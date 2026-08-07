import 'package:equatable/equatable.dart';
import '../../../../core/utils/date_utils.dart';

class GroupInvite extends Equatable {
  final String id;
  final String groupId;
  final String groupName;
  final String? invitedByName;
  final DateTime createdAt;

  const GroupInvite({
    required this.id,
    required this.groupId,
    required this.groupName,
    this.invitedByName,
    required this.createdAt,
  });

  factory GroupInvite.fromJson(Map<String, dynamic> j) => GroupInvite(
        id: j['id'] as String,
        groupId: j['groupId'] as String,
        groupName: j['groupName'] as String? ?? '',
        invitedByName: j['invitedByName'] as String?,
        createdAt: AppDateUtils.parseOrNow(j['createdAt'] as String?),
      );

  @override
  List<Object?> get props => [id];
}

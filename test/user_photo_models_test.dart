import 'package:bratnava_fc_app/features/dashboard/domain/entities/my_player.dart';
import 'package:bratnava_fc_app/features/members/domain/entities/app_user.dart';
import 'package:bratnava_fc_app/features/members/domain/entities/group_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const photoUrl = '/api/Users/00000000-0000-0000-0000-000000000001/photo?v=1';

  test('AppUser reads profile photo metadata', () {
    final user = AppUser.fromJson({
      'id': 'user-1',
      'firstName': 'Ana',
      'lastName': 'Silva',
      'email': 'ana@example.com',
      'userName': 'ana',
      'photoUrl': photoUrl,
      'photoUpdatedAt': '2026-08-10T10:00:00Z',
    });

    expect(user.photoUrl, photoUrl);
    expect(user.photoUpdatedAt, '2026-08-10T10:00:00Z');
  });

  test('player models inherit the linked user photo URL', () {
    const groupLogoUrl = '/api/Groups/group-1/logo?v=2';
    final myPlayer = MyPlayer.fromJson({
      'playerId': 'player-1',
      'groupId': 'group-1',
      'groupName': 'Patota',
      'playerName': 'Ana',
      'photoUrl': photoUrl,
      'groupLogoUrl': groupLogoUrl,
    });
    final groupPlayer = GroupPlayer.fromJson({
      'id': 'player-1',
      'groupId': 'group-1',
      'name': 'Ana',
      'photoUrl': photoUrl,
    });

    expect(myPlayer.photoUrl, photoUrl);
    expect(myPlayer.groupLogoUrl, groupLogoUrl);
    expect(groupPlayer.photoUrl, photoUrl);
  });
}

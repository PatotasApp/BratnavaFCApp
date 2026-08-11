import 'package:bratnava_fc_app/features/dashboard/domain/entities/my_player.dart';
import 'package:bratnava_fc_app/features/members/domain/entities/app_user.dart';
import 'package:bratnava_fc_app/features/members/domain/entities/group_player.dart';
import 'package:bratnava_fc_app/features/matches/domain/entities/match_models.dart';
import 'package:bratnava_fc_app/features/player_spotlight/domain/entities/spotlight_report.dart';
import 'package:bratnava_fc_app/features/history/domain/entities/match_details.dart'
    as history;
import 'package:flutter_test/flutter_test.dart';

void main() {
  const photoUrl = '/api/Users/00000000-0000-0000-0000-000000000001/photo?v=1';

  test('AppUser reads profile photo metadata', () {
    final user = AppUser.fromJson(const {
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
    final myPlayer = MyPlayer.fromJson(const {
      'playerId': 'player-1',
      'userId': 'user-1',
      'groupId': 'group-1',
      'groupName': 'Patota',
      'playerName': 'Ana',
      'photoUrl': photoUrl,
      'groupLogoUrl': groupLogoUrl,
    });
    final groupPlayer = GroupPlayer.fromJson(const {
      'id': 'player-1',
      'groupId': 'group-1',
      'name': 'Ana',
      'photoUrl': photoUrl,
    });

    expect(myPlayer.photoUrl, photoUrl);
    expect(myPlayer.userId, 'user-1');
    expect(myPlayer.groupLogoUrl, groupLogoUrl);
    expect(groupPlayer.photoUrl, photoUrl);
  });

  test('match player reads the user link used to open the profile', () {
    final player = MatchPlayerInfo.fromJson(const {
      'matchPlayerId': 'match-player-1',
      'playerId': 'player-1',
      'userId': 'user-1',
      'playerName': 'Ana',
      'photoUrl': photoUrl,
    });

    expect(player.userId, 'user-1');
    expect(player.photoUrl, photoUrl);
  });

  test('history lineup player reads profile photo and user link', () {
    final details = history.MatchDetails.fromJson(const {
      'matchId': 'match-1',
      'teamAPlayers': [
        {
          'matchPlayerId': 'match-player-1',
          'playerId': 'player-1',
          'userId': 'user-1',
          'playerName': 'Ana',
          'photoUrl': photoUrl,
        },
      ],
      'teamBPlayers': <Map<String, dynamic>>[],
    });

    expect(details.teamAPlayers.single.userId, 'user-1');
    expect(details.teamAPlayers.single.photoUrl, photoUrl);
  });

  test('spotlight player reads the user link returned by the backend', () {
    final player = SpotlightPlayer.fromJson(const {
      'playerId': 'player-1',
      'userId': 'user-1',
      'name': 'Ana',
    });
    final legacyCasing = SpotlightPlayer.fromJson(const {
      'playerId': 'player-2',
      'UserId': 'user-2',
      'name': 'Bia',
    });

    expect(player.userId, 'user-1');
    expect(legacyCasing.userId, 'user-2');
  });
}

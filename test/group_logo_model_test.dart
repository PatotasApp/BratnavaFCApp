import 'package:patotas_app/features/group_settings/domain/entities/group_settings.dart';
import 'package:patotas_app/features/groups/domain/entities/group_invite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GroupDetail reads logo metadata', () {
    final group = GroupDetail.fromJson({
      'id': 'group-1',
      'name': 'Patota',
      'logoUrl': '/api/Groups/group-1/logo?v=2',
      'logoUpdatedAt': '2026-08-10T12:00:00Z',
    });

    expect(group.logoUrl, '/api/Groups/group-1/logo?v=2');
    expect(group.logoUpdatedAt, DateTime.parse('2026-08-10T12:00:00Z'));
  });

  test('GroupInvite reads the patota logo URL', () {
    final invite = GroupInvite.fromJson({
      'id': 'invite-1',
      'groupId': 'group-1',
      'groupName': 'Patota',
      'groupLogoUrl': '/api/Groups/group-1/logo?v=2',
      'createdAt': '2026-08-10T12:00:00Z',
    });

    expect(invite.groupLogoUrl, '/api/Groups/group-1/logo?v=2');
  });
}

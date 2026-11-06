import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/notifications/data/datasources/notifications_datasource.dart';

void main() {
  test('avisos de aposta ficam escondidos no app', () {
    expect(isHiddenNotificationType('bet_created'), isTrue);
    expect(isHiddenNotificationType('bet_resolved'), isTrue);
    expect(isHiddenNotificationType('match_invite'), isFalse);
    expect(isHiddenNotificationType(null), isFalse);
  });
}

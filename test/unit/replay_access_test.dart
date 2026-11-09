import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/core/constants/replay_access.dart';
import 'package:patotas_app/features/shell/domain/shell_navigation_policy.dart';

void main() {
  const bratnava = '3f401edf-d309-4bae-97d8-28eae0da7a8a';

  test('só a patota com câmeras tem replay', () {
    expect(groupHasReplays(bratnava), isTrue);
    expect(groupHasReplays(bratnava.toUpperCase()), isTrue);
    expect(groupHasReplays('00000000-0000-0000-0000-000000000001'), isFalse);
    expect(groupHasReplays(null), isFalse);
  });

  test('identifica Bratnava FC pelo nome normalizado', () {
    expect(isBratnavaFcGroup('Bratnava FC'), isTrue);
    expect(isBratnavaFcGroup('  BRATNAVA   FC '), isTrue);
    expect(isBratnavaFcGroup('Resenha FC'), isFalse);
    expect(isBratnavaFcGroup(null), isFalse);
  });

  test('menu Replays some fora da patota com câmeras', () {
    bool visible(String? groupName) => isShellMenuItemVisible(
        path: '/app/replays',
        isAdmin: true,
        canSeeStats: true,
        groupName: groupName);

    expect(visible('Bratnava FC'), isTrue);
    expect(visible('Resenha FC'), isFalse);
    expect(visible(null), isFalse);
  });
}

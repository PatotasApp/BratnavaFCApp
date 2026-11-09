import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/core/constants/replay_access.dart';
import 'package:patotas_app/features/shell/domain/shell_navigation_policy.dart';

void main() {
  test('identifica Bratnava FC pelo ID estável', () {
    const bratnava = '3f401edf-d309-4bae-97d8-28eae0da7a8a';
    expect(groupHasReplays(bratnava), isTrue);
    expect(groupHasReplays(bratnava.toUpperCase()), isTrue);
    expect(groupHasReplays('00000000-0000-0000-0000-000000000001'), isFalse);
    expect(groupHasReplays(null), isFalse);
  });

  test('menu Replays some fora da patota com câmeras', () {
    bool visible(bool canSeeReplays) => isShellMenuItemVisible(
        path: '/app/replays',
        isAdmin: true,
        canSeeStats: true,
        canSeeReplays: canSeeReplays);

    expect(visible(true), isTrue);
    expect(visible(false), isFalse);
  });
}

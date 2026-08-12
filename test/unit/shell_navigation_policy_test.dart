import 'package:patotas_app/features/shell/domain/shell_navigation_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shellNavigationIndexForPath', () {
    test('seleciona as quatro áreas principais', () {
      expect(shellNavigationIndexForPath('/app'), 0);
      expect(shellNavigationIndexForPath('/app/matches'), 1);
      expect(shellNavigationIndexForPath('/app/groups'), 2);
      expect(shellNavigationIndexForPath('/app/history'), 3);
    });

    test('mantém a área pai selecionada em uma rota interna', () {
      expect(shellNavigationIndexForPath('/app/matches/partida-1'), 1);
      expect(shellNavigationIndexForPath('/app/groups/patota-1'), 2);
      expect(shellNavigationIndexForPath('/app/history/g-1/m-1'), 3);
    });

    test('seleciona Mais nas demais telas autenticadas', () {
      expect(shellNavigationIndexForPath('/app/polls/votes'), 4);
      expect(shellNavigationIndexForPath('/app/conquistas'), 4);
      expect(shellNavigationIndexForPath('/app/account'), 4);
    });
  });

  group('isShellMenuItemVisible', () {
    test('oculta todos os menus administrativos de usuários comuns', () {
      for (final path in shellAdminOnlyMenuPaths) {
        expect(
          isShellMenuItemVisible(
            path: path,
            isAdmin: false,
            canSeeStats: false,
          ),
          isFalse,
          reason: '$path não pode aparecer para usuário comum',
        );
      }
    });

    test('inclui Conquistas entre os menus exclusivos do administrador', () {
      expect(shellAdminOnlyMenuPaths, contains('/app/conquistas'));
      expect(
        isShellMenuItemVisible(
          path: '/app/conquistas',
          isAdmin: true,
          canSeeStats: false,
        ),
        isTrue,
      );
    });

    test('mantém menus comuns visíveis para qualquer membro', () {
      expect(
        isShellMenuItemVisible(
          path: '/app/calendar',
          isAdmin: false,
          canSeeStats: false,
        ),
        isTrue,
      );
    });

    test('respeita separadamente a permissão para estatísticas', () {
      expect(
        isShellMenuItemVisible(
          path: '/app/visual-stats',
          isAdmin: false,
          canSeeStats: false,
          requiresStatsPermission: true,
        ),
        isFalse,
      );
      expect(
        isShellMenuItemVisible(
          path: '/app/visual-stats',
          isAdmin: false,
          canSeeStats: true,
          requiresStatsPermission: true,
        ),
        isTrue,
      );
    });
  });
}

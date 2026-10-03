import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/auth/data/datasources/auth_remote_datasource.dart';

/// A recusa 409 do `DELETE /api/Users/me` traz as patotas bloqueadoras no
/// `data` do envelope de erro. Sem elas a tela não consegue dizer ONDE a pessoa
/// precisa promover outro administrador — daí o parser ser testado à parte.
void main() {
  group('AuthRemoteDataSource.parsePendingAdminGroups', () {
    test('envelope de erro com lista de patotas', () {
      final data = {
        'success': false,
        'error': 'Você é o único administrador de 2 patota(s).',
        'data': [
          {'groupId': 'g1', 'groupName': 'Pelada de Quinta'},
          {'groupId': 'g2', 'groupName': 'Bratnava FC'},
        ],
      };

      final groups = AuthRemoteDataSource.parsePendingAdminGroups(data);

      expect(groups, hasLength(2));
      expect(groups.first.groupId, 'g1');
      expect(groups.map((g) => g.groupName), [
        'Pelada de Quinta',
        'Bratnava FC',
      ]);
    });

    test('lista crua também é aceita', () {
      final groups = AuthRemoteDataSource.parsePendingAdminGroups([
        {'id': 'g1', 'name': 'Bratnava FC'},
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.groupId, 'g1');
      expect(groups.single.groupName, 'Bratnava FC');
    });

    test('formato inesperado vira lista vazia, não exceção', () {
      expect(AuthRemoteDataSource.parsePendingAdminGroups(null), isEmpty);
      expect(AuthRemoteDataSource.parsePendingAdminGroups({'x': 1}), isEmpty);
      expect(
        AuthRemoteDataSource.parsePendingAdminGroups({
          'data': [
            {'groupId': 'g1', 'groupName': '  '},
          ],
        }),
        isEmpty,
      );
    });
  });
}

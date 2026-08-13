import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/replays/data/datasources/replays_remote_datasource.dart';

/// Regressão: a paginação do backend passou a devolver
/// `{ data: { page, pageSize, total, items: [...] } }`. O parser precisa
/// tolerar esse formato (antes retornava lista vazia → "nenhum replay").
void main() {
  group('ReplaysRemoteDataSource.unwrapList', () {
    test('array cru', () {
      final data = [
        {'clipId': 'a'},
        {'clipId': 'b'},
      ];
      final out = ReplaysRemoteDataSource.unwrapList(data);
      expect(out, hasLength(2));
      expect(out.first['clipId'], 'a');
    });

    test('envelope ApiResponse com data: [ ... ]', () {
      final data = {
        'success': true,
        'data': [
          {'clipId': 'a'},
        ],
      };
      final out = ReplaysRemoteDataSource.unwrapList(data);
      expect(out, hasLength(1));
      expect(out.first['clipId'], 'a');
    });

    test('envelope + PagedResultDto (formato novo)', () {
      final data = {
        'success': true,
        'data': {
          'page': 1,
          'pageSize': 20,
          'total': 42,
          'items': [
            {'clipId': 'a'},
            {'clipId': 'b'},
            {'clipId': 'c'},
          ],
        },
      };
      final out = ReplaysRemoteDataSource.unwrapList(data);
      expect(out, hasLength(3));
      expect(out.map((e) => e['clipId']), ['a', 'b', 'c']);
    });

    test('formato desconhecido → lista vazia', () {
      expect(ReplaysRemoteDataSource.unwrapList({'x': 1}), isEmpty);
      expect(ReplaysRemoteDataSource.unwrapList(null), isEmpty);
    });
  });

  group('ReplaysRemoteDataSource.extractTotal', () {
    test('lê total do PagedResultDto', () {
      final data = {
        'data': {'total': 42, 'items': <dynamic>[]},
      };
      expect(ReplaysRemoteDataSource.extractTotal(data), 42);
    });

    test('array cru não tem total', () {
      expect(ReplaysRemoteDataSource.extractTotal([]), isNull);
    });

    test('envelope com data: [ ... ] não tem total', () {
      expect(ReplaysRemoteDataSource.extractTotal({'data': <dynamic>[]}), isNull);
    });
  });
}

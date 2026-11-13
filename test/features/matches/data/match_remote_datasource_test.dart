import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/matches/data/datasources/match_remote_datasource.dart';

class _RequestRecorder extends Interceptor {
  final calls = <RequestOptions>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    calls.add(options);
    handler.resolve(
      Response<void>(requestOptions: options, statusCode: 204),
    );
  }
}

void main() {
  test('troca de função usa PATCH e envia o papel escolhido', () async {
    final recorder = _RequestRecorder();
    final datasource = MatchRemoteDataSource(
      Dio()..interceptors.add(recorder),
    );

    await datasource.setPlayerRole('group-1', 'match-1', 'player-1', true);

    final call = recorder.calls.single;
    expect(call.method, 'PATCH');
    expect(
      call.path,
      '/api/Matches/group/group-1/match-1/players/player-1/role',
    );
    expect(call.data, {'isGoalkeeper': true});
  });
}

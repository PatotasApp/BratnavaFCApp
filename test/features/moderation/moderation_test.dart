import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/moderation/moderation.dart';

/// Guarda as chamadas e responde 200, sem rede.
class _Recorder extends Interceptor {
  final calls = <RequestOptions>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    calls.add(options);
    final data = options.path.endsWith('/blocks')
        ? {
            'data': [
              {'userId': 'u2', 'name': 'Caio'}
            ]
          }
        : {'success': true};
    handler.resolve(
        Response(requestOptions: options, statusCode: 200, data: data));
  }
}

void main() {
  late _Recorder recorder;
  late ModerationDataSource ds;

  setUp(() {
    recorder = _Recorder();
    ds = ModerationDataSource(Dio()..interceptors.add(recorder));
  });

  test('denúncia manda tipo, alvo, patota e motivo', () async {
    await ds.report(
        target: ReportTarget.replay,
        targetId: 'c1',
        groupId: 'g1',
        reason: 'Violência',
        details: '  xingou  ');

    final call = recorder.calls.single;
    expect(call.method, 'POST');
    expect(call.path, '/api/reports');
    expect(call.data, {
      'targetType': 2,
      'targetId': 'c1',
      'groupId': 'g1',
      'reason': 'Violência',
      'details': 'xingou',
    });
  });

  test('bloquear, desbloquear e listar usam as rotas da API', () async {
    await ds.block('u2');
    await ds.unblock('u2');
    final list = await ds.blocked();

    expect(recorder.calls.map((c) => '${c.method} ${c.path}'), [
      'POST /api/users/u2/block',
      'DELETE /api/users/u2/block',
      'GET /api/users/me/blocks',
    ]);
    expect(list.single.name, 'Caio');
  });

  testWidgets('o envio só libera depois de escolher o motivo', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [moderationDsProvider.overrideWithValue(ds)],
      child: const MaterialApp(
          home: Scaffold(
              body: ReportSheet(target: ReportTarget.user, targetId: 'u9'))),
    ));

    FilledButton button() =>
        tester.widget<FilledButton>(find.byType(FilledButton));
    expect(find.text('Denunciar perfil'), findsOneWidget);
    expect(button().onPressed, isNull);

    await tester.tap(find.text('Spam ou golpe'));
    await tester.pump();
    expect(button().onPressed, isNotNull);
  });
}

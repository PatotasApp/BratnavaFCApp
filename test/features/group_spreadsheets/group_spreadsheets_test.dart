import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/core/push/notification_router.dart';
import 'package:patotas_app/features/group_spreadsheets/group_spreadsheets.dart';
import 'package:patotas_app/features/group_spreadsheets/presentation/spreadsheet_widgets.dart';

/// Guarda as chamadas e responde como a API, sem rede.
class _FakeApi extends Interceptor {
  final calls = <RequestOptions>[];
  int failUploadsWithStatus = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    calls.add(options);
    if (options.method == 'POST' && failUploadsWithStatus > 0) {
      handler.reject(DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: failUploadsWithStatus,
          data: {'success': false, 'error': 'A planilha deve ter no máximo 10 MB.'},
        ),
      ));
      return;
    }
    final data = switch (options.method) {
      'GET' => {
          'success': true,
          'data': [_json(status: 1, adminNote: 'Começamos hoje')],
        },
      'POST' => {
          'success': true,
          'data': _json(kind: (options.data as FormData).fields.firstWhere((f) => f.key == 'kind').value),
        },
      _ => {'success': true},
    };
    handler.resolve(Response(requestOptions: options, statusCode: 200, data: data));
  }
}

Map<String, dynamic> _json({Object status = 0, Object kind = 0, String? adminNote}) => {
      'id': 's1',
      'groupId': 'g1',
      'groupName': 'Resenha FC',
      'kind': kind,
      'fileName': 'Jogos 2025.xlsx',
      'sizeBytes': 2048,
      'note': null,
      'status': status,
      'adminNote': adminNote,
      'uploadedByUserId': 'u1',
      'uploadedByName': 'Alexandre Pires',
      'uploadedByEmail': null,
      'createdAt': '2026-11-06T15:00:00Z',
      'statusChangedAt': null,
    };

void main() {
  group('modelo e regras', () {
    test('lê o DTO da API', () {
      final s = GroupSpreadsheet.fromJson(_json(status: 2, kind: 1, adminNote: 'ok'));
      expect(s.kind, SpreadsheetKind.payments);
      expect(s.status, SpreadsheetStatus.finished);
      expect(s.status.label, 'Finalizada');
      expect(s.adminNote, 'ok');
      expect(s.sizeBytes, 2048);
      expect(s.canDelete, isFalse);
      expect(GroupSpreadsheet.fromJson(_json()).canDelete, isTrue);
    });

    test('valida extensão e tamanho como a API', () {
      expect(SpreadsheetFileRules.validate('a.xlsx', 10), isNull);
      expect(SpreadsheetFileRules.validate('A.CSV', 10), isNull);
      expect(SpreadsheetFileRules.validate('a.ods', 10), isNull);
      expect(SpreadsheetFileRules.validate('a.pdf', 10), isNull);
      expect(SpreadsheetFileRules.validate('a.exe', 10), contains('.xlsx'));
      expect(SpreadsheetFileRules.validate('semextensao', 10), isNotNull);
      expect(SpreadsheetFileRules.validate('a.xls', 0), isNotNull);
      expect(SpreadsheetFileRules.validate('a.xls', 10 * 1024 * 1024 + 1), contains('10 MB'));
      expect(SpreadsheetFileRules.contentTypeOf('a.csv').mimeType, 'text/csv');
      expect(SpreadsheetFileRules.formatSize(3 * 1024 * 1024 + 512 * 1024), '3,5 MB');
    });

    test('id da patota criada na resposta do POST /api/Groups', () {
      const id = '3f2a0c1d-1111-2222-3333-444455556666';
      expect(createdGroupIdFrom({'success': true, 'data': id}), id);
      expect(createdGroupIdFrom({'data': {'id': id}}), id);
      expect(createdGroupIdFrom({'success': true}), isNull);
      expect(createdGroupIdFrom('qualquer coisa'), isNull);
    });

    test('notificação de planilha abre a tela da patota', () {
      expect(notificationRoute('group_spreadsheet', {'groupId': 'g1'}), '/app/spreadsheets?groupId=g1');
      expect(notificationRoute('group_spreadsheet', {}), '/app/spreadsheets');
    });
  });

  group('datasource', () {
    late _FakeApi api;
    late GroupSpreadsheetsDataSource ds;

    setUp(() {
      api = _FakeApi();
      ds = GroupSpreadsheetsDataSource(Dio()..interceptors.add(api));
    });

    test('envia multipart com tipo, observação e arquivo', () async {
      final result = await ds.upload(
        groupId: 'g1',
        kind: SpreadsheetKind.payments,
        file: PickedSpreadsheet('Pagamentos.csv', Uint8List.fromList([1, 2, 3])),
        note: '  só 2025 ',
      );

      final call = api.calls.single;
      expect(call.method, 'POST');
      expect(call.path, '/api/groups/g1/spreadsheets');
      final form = call.data as FormData;
      expect({for (final f in form.fields) f.key: f.value}, {'kind': '1', 'note': 'só 2025'});
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, 'Pagamentos.csv');
      expect(form.files.single.value.contentType?.mimeType, 'text/csv');
      expect(result?.kind, SpreadsheetKind.payments);
    });

    test('lista e remove', () async {
      final list = await ds.list('g1');
      expect(list.single.status, SpreadsheetStatus.inProgress);
      expect(list.single.adminNote, 'Começamos hoje');

      await ds.delete('g1', 's1');
      expect(api.calls.last.method, 'DELETE');
      expect(api.calls.last.path, '/api/groups/g1/spreadsheets/s1');
    });
  });

  group('formulário de envio', () {
    Future<_FakeApi> pump(WidgetTester tester, {required void Function(List<GroupSpreadsheet>) onSent,
        Future<PickedSpreadsheet?> Function()? picker, VoidCallback? onSkip}) async {
      final api = _FakeApi();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          groupSpreadsheetsDsProvider.overrideWithValue(GroupSpreadsheetsDataSource(Dio()..interceptors.add(api))),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SpreadsheetUploadForm(
                groupId: 'g1',
                onSent: onSent,
                onSkip: onSkip,
                skipLabel: 'Não tenho / enviar depois',
                picker: picker ?? () async => PickedSpreadsheet('Jogos.xlsx', Uint8List.fromList([80, 75, 3, 4])),
              ),
            ),
          ),
        ),
      ));
      return api;
    }

    testWidgets('pergunta pelos dois tipos e envia só o escolhido', (tester) async {
      List<GroupSpreadsheet>? sent;
      final api = await pump(tester, onSent: (s) => sent = s);

      expect(find.text('Planilha de histórico de jogos'), findsOneWidget);
      expect(find.text('Planilha de pagamentos'), findsOneWidget);
      final submit = find.byKey(const Key('spreadsheet-submit'));
      expect(tester.widget<FilledButton>(submit).onPressed, isNull, reason: 'sem arquivo não envia');

      await tester.tap(find.byKey(const Key('pick-matches')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Jogos.xlsx'), findsOneWidget);

      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(api.calls, hasLength(1));
      expect((api.calls.single.data as FormData).fields.firstWhere((f) => f.key == 'kind').value, '0');
      expect(sent, hasLength(1));
    });

    testWidgets('arquivo inválido mostra o motivo e não envia', (tester) async {
      final api = await pump(tester,
          onSent: (_) {}, picker: () async => throw const FormatException('Envie a planilha em .xlsx, .xls, .csv, .ods ou .pdf.'));

      await tester.tap(find.byKey(const Key('pick-payments')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Envie a planilha em'), findsOneWidget);
      expect(api.calls, isEmpty);
    });

    testWidgets('erro da API aparece e o arquivo continua para tentar de novo', (tester) async {
      var sentCalled = false;
      final api = await pump(tester, onSent: (_) => sentCalled = true);
      api.failUploadsWithStatus = 400;

      await tester.tap(find.byKey(const Key('pick-matches')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('spreadsheet-submit')));
      await tester.pumpAndSettle();

      expect(find.text('A planilha deve ter no máximo 10 MB.'), findsOneWidget);
      expect(find.textContaining('Jogos.xlsx'), findsOneWidget);
      expect(sentCalled, isFalse);
    });

    testWidgets('pular chama o callback sem enviar nada', (tester) async {
      var skipped = false;
      final api = await pump(tester, onSent: (_) {}, onSkip: () => skipped = true);

      await tester.tap(find.text('Não tenho / enviar depois'));
      await tester.pump();

      expect(skipped, isTrue);
      expect(api.calls, isEmpty);
    });
  });
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/core/share/pending_share_link.dart';
import 'package:patotas_app/core/share/share_links.dart';
import 'package:patotas_app/features/share/data/share_api.dart';
import 'package:patotas_app/features/share/presentation/share_link_page.dart';

const _id = '3f2a1c9e-1b2d-4c5e-8f90-123456789abc';

class _FakeShareApi extends ShareApi {
  final ShareResolution? resolution;
  final PublicGroupResponse? groupResponse;

  _FakeShareApi({this.resolution, this.groupResponse}) : super(Dio());

  @override
  Future<ShareResolution?> resolve(ShareKind kind, String id) async =>
      resolution;

  @override
  Future<PublicGroupResponse?> group(String groupId) async => groupResponse;
}

Widget _app(Widget child, ShareApi api) => ProviderScope(
      overrides: [shareApiProvider.overrideWithValue(api)],
      child: MaterialApp(home: child),
    );

void main() {
  group('links', () {
    test('monta os caminhos iguais aos do site', () {
      const base = 'https://site.test/';
      expect(ShareLinks.build(ShareKind.profile, _id, base: base),
          'https://site.test/perfil/$_id');
      expect(ShareLinks.build(ShareKind.group, _id, base: base),
          'https://site.test/patota/$_id');
      expect(ShareLinks.build(ShareKind.match, _id, base: base),
          endsWith('/partida/$_id'));
      expect(ShareLinks.build(ShareKind.mvp, _id, base: base),
          endsWith('/votacao/$_id'));
      expect(ShareLinks.build(ShareKind.championship, _id, base: base),
          endsWith('/campeonato/$_id'));
      expect(ShareLinks.build(ShareKind.poll, _id, base: base),
          endsWith('/enquete/$_id'));
    });

    test('reconhece link completo e só o caminho', () {
      expect(ShareTarget.parse(Uri.parse('https://x.dev/partida/$_id')),
          const ShareTarget(ShareKind.match, _id));
      expect(ShareTarget.parse(Uri.parse('/perfil/$_id')),
          const ShareTarget(ShareKind.profile, _id));
      expect(ShareTarget.parse(Uri.parse('/partida/nao-e-guid')), isNull);
      expect(ShareTarget.parse(Uri.parse('/app/matches')), isNull);
      expect(ShareTarget.parse(Uri.parse('/pagamento/$_id')), isNull);
    });

    test('guarda o link durante splash/login e entrega uma vez', () {
      final pending = PendingShareLink();
      pending.remember(Uri.parse('/app/matches'));
      expect(pending.location, isNull);
      pending.remember(Uri.parse('/enquete/$_id'));
      expect(pending.take(), '/enquete/$_id');
      expect(pending.take(), isNull);
    });

    testWidgets('oferece copiar o link ou compartilhar em outro app',
        (tester) async {
      MethodCall? clipboardCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clipboardCall = call;
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => shareLink(
                context,
                'https://site.test/partida/$_id',
                text: 'Partida no PatotasApp',
              ),
              child: const Text('Compartilhar'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Compartilhar'));
      await tester.pumpAndSettle();

      expect(find.text('Copiar link'), findsOneWidget);
      expect(find.text('Compartilhar em…'), findsOneWidget);

      await tester.tap(find.text('Copiar link'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(clipboardCall?.arguments, {
        'text': 'https://site.test/partida/$_id',
      });
      expect(find.text('Link copiado!'), findsOneWidget);
    });
  });

  group('rota interna', () {
    ShareResolution r(String kind, {String? status, String? pollType}) =>
        ShareResolution(
            kind: kind,
            id: 'x',
            access: 'member',
            groupId: 'g',
            matchStatus: status,
            pollType: pollType);

    test('por tipo e status', () {
      expect(internalRouteFor(r('match', status: 'Finalized')),
          '/app/history/g/x');
      expect(internalRouteFor(r('mvp', status: 'PostGame')),
          '/app/matches?matchId=x');
      expect(internalRouteFor(r('championship')), '/app/championships/x');
      expect(internalRouteFor(r('poll', pollType: 'event')),
          '/app/polls/events?pollId=x');
      expect(internalRouteFor(r('poll', pollType: 'poll')),
          '/app/polls/votes?pollId=x');
    });

    test('lê a resposta da API', () {
      final res = ShareResolution.fromJson({
        'kind': 'match',
        'id': _id,
        'access': 'not_member',
        'groupName': 'Resenha FC',
      });
      expect(res.isMember, isFalse);
      expect(res.groupName, 'Resenha FC');
    });

    test('descreve dia e horário como o site', () {
      PublicGroup g(int? day, String? time) => PublicGroup(
          groupId: 'g',
          name: 'n',
          sinceYear: 2024,
          membersCount: 1,
          matchesPlayed: 1,
          goalsScored: 1,
          dayOfWeek: day,
          kickoffTime: time);
      expect(g(4, '20:00').schedule, 'Toda quinta, 20h');
      expect(g(0, '19:30').schedule, 'Todo domingo, 19h30');
      expect(g(null, null).schedule, isNull);
    });
  });

  group('telas do link', () {
    testWidgets('não integrante vê só o aviso', (tester) async {
      await tester.pumpWidget(_app(
        const SharedContentLinkPage(kind: ShareKind.match, id: _id),
        _FakeShareApi(
            resolution: const ShareResolution(
                kind: 'match',
                id: _id,
                access: 'not_member',
                groupName: 'Resenha FC')),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Só para integrantes'), findsOneWidget);
      expect(find.textContaining('Esta partida é da patota Resenha FC'),
          findsOneWidget);
    });

    testWidgets('link inexistente', (tester) async {
      await tester.pumpWidget(_app(
        const SharedContentLinkPage(kind: ShareKind.poll, id: _id),
        _FakeShareApi(),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Link não encontrado'), findsOneWidget);
    });

    testWidgets('patota pública mostra a vitrine', (tester) async {
      await tester.pumpWidget(_app(
        const SharedGroupLinkPage(groupId: _id),
        _FakeShareApi(
          groupResponse: const PublicGroupResponse(
            enabled: true,
            isMember: false,
            group: PublicGroup(
                groupId: _id,
                name: 'Resenha FC',
                sinceYear: 2024,
                membersCount: 18,
                matchesPlayed: 40,
                goalsScored: 300,
                dayOfWeek: 4,
                kickoffTime: '20:00',
                placeName: 'Arena'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Resenha FC'), findsWidgets);
      expect(find.text('Toda quinta, 20h'), findsOneWidget);
      expect(find.text('Arena'), findsOneWidget);
      expect(find.text('Abrir a patota'), findsNothing);
    });

    testWidgets('patota com página desligada', (tester) async {
      await tester.pumpWidget(_app(
        const SharedGroupLinkPage(groupId: _id),
        _FakeShareApi(
            groupResponse:
                const PublicGroupResponse(enabled: false, isMember: false)),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Patota privada'), findsOneWidget);
    });
  });
}

import 'package:patotas_app/core/theme/app_theme.dart';
import 'package:patotas_app/features/auth/domain/entities/account.dart';
import 'package:patotas_app/features/auth/presentation/providers/account_store.dart';
import 'package:patotas_app/features/group_settings/domain/entities/group_settings.dart';
import 'package:patotas_app/features/group_settings/presentation/providers/group_settings_provider.dart';
import 'package:patotas_app/features/matches/data/datasources/match_remote_datasource.dart';
import 'package:patotas_app/features/matches/domain/entities/match_models.dart';
import 'package:patotas_app/features/matches/presentation/pages/step3_matchmaking_page.dart';
import 'package:patotas_app/features/matches/presentation/providers/match_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeMatchNotifier extends MatchNotifier {
  _FakeMatchNotifier(MatchState initial)
      : super(MatchRemoteDataSource(Dio()), 'group-1', true) {
    state = initial;
  }
}

class _FakeAccountStore extends AccountStore {
  _FakeAccountStore(super.prefs) {
    state = const AccountState(
      activeAccountId: 'user-1',
      accounts: [
        Account(
          userId: 'user-1',
          name: 'Usuário teste',
          email: 'teste@example.com',
          roles: ['Admin'],
          accessToken: 'token',
          refreshToken: 'refresh',
          activeGroupId: 'group-1',
          groupAdminIds: ['group-1'],
        ),
      ],
    );
  }
}

void main() {
  test('jogadores continuam disponiveis para refazer times apos atribuicao',
      () {
    MatchPlayerInfo player(int index, int team) => MatchPlayerInfo.fromJson({
          'matchPlayerId': 'match-player-$index',
          'playerId': 'player-$index',
          'playerName': 'Jogador $index',
          'team': team,
        });

    final teamA = List.generate(6, (index) => player(index, 1));
    final teamB = List.generate(6, (index) => player(index + 6, 2));
    final state = MatchState(
      teamAPlayers: teamA,
      teamBPlayers: teamB,
      participants: [teamA.first],
      acceptedPlayers: const [],
    );

    expect(state.formationPlayers, hasLength(12));
  });

  testWidgets('geração mostra cinco métodos, goleiros e botão fixo no Pixel 5',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final players = List.generate(
      12,
      (index) => MatchPlayerInfo.fromJson({
        'matchPlayerId': 'match-player-$index',
        'playerId': 'player-$index',
        'playerName': 'Jogador ${index + 1}',
        'isGoalkeeper': index < 2,
      }),
    );
    final notifier = _FakeMatchNotifier(
      MatchState(
        matchId: 'match-1',
        groupId: 'group-1',
        step: MatchStep.teams,
        acceptedPlayers: players,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchNotifierProvider.overrideWith((ref) => notifier),
          accountStoreProvider.overrideWith(
            (ref) => _FakeAccountStore(prefs),
          ),
          groupSettingsProvider.overrideWith(
            (ref, groupId) => Future.value(GroupSettings.defaults()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: Step3MatchmakingPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    for (final label in [
      'Manual',
      'Aleatório',
      'Algoritmo',
      'Por vitórias',
      'Por perfil',
      'Incluir goleiros',
      'Gerar times',
    ]) {
      expect(find.text(label), findsAtLeastNWidgets(1));
    }
    expect(tester.takeException(), isNull);

    final buttonBefore = tester.getRect(find.text('Gerar times'));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();
    final buttonAfter = tester.getRect(find.text('Gerar times'));

    expect(buttonAfter.top, closeTo(buttonBefore.top, 0.1));
    expect(buttonAfter.bottom, lessThanOrEqualTo(850));
    expect(tester.takeException(), isNull);
  });
}

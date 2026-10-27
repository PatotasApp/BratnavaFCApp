import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/championships/data/datasources/championship_mock_datasource.dart';
import 'package:patotas_app/features/championships/domain/entities/championship_enums.dart';
import 'package:patotas_app/features/championships/presentation/providers/championship_provider.dart';

void main() {
  // No mock, o campeonato em TeamDraw tem 3 times de 3; o 1º de cada time é
  // o goleiro (player-1, player-4 e player-7).
  const id = 'championship-2';
  String player(int index) => '$id-player-$index';
  String team(int index) => '$id-team-$index';

  Future<ChampionshipDetailsNotifier> loaded() async {
    final notifier =
        ChampionshipDetailsNotifier(ChampionshipMockDataSource(), 'g', id);
    await notifier.load();
    return notifier;
  }

  test('trocar goleiro com jogador de outro time leva o papel junto', () async {
    final notifier = await loaded();

    expect(await notifier.swapPlayers(player(1), player(5)), isTrue);

    final details = notifier.state.details!;
    expect(details.playerById(player(5))!.teamId, team(1));
    expect(details.playerById(player(5))!.isGoalkeeper, isTrue);
    expect(details.playerById(player(1))!.teamId, team(2));
    expect(details.playerById(player(1))!.isGoalkeeper, isFalse);
    expect(details.playerById(player(4))!.isGoalkeeper, isTrue);
  });

  test('no mesmo time, a troca passa o goleiro para o outro', () async {
    final notifier = await loaded();

    await notifier.swapPlayers(player(2), player(1));

    final details = notifier.state.details!;
    expect(details.playerById(player(2))!.isGoalkeeper, isTrue);
    expect(details.playerById(player(1))!.isGoalkeeper, isFalse);
  });

  test('voltar etapa desfaz os times e volta para a presença', () async {
    final notifier = await loaded();

    expect(await notifier.stepBack(), isTrue);

    final details = notifier.state.details!;
    expect(details.status, ChampionshipStatus.acceptation);
    expect(details.teams, isEmpty);
    expect(details.players.every((p) => p.teamId == null), isTrue);
  });
}

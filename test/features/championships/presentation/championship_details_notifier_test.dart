import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/championships/data/datasources/championship_mock_datasource.dart';
import 'package:patotas_app/features/championships/domain/entities/championship_enums.dart';
import 'package:patotas_app/features/championships/domain/entities/championship_models.dart';
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

  test('trocar o goleiro com alguém de outro time: o goleiro vai junto',
      () async {
    final notifier = await loaded();

    expect(await notifier.swapPlayers(player(1), player(5)), isTrue);

    final details = notifier.state.details!;
    expect(details.playerById(player(5))!.teamId, team(1));
    expect(details.playerById(player(5))!.isGoalkeeper, isFalse);
    expect(details.playerById(player(1))!.teamId, team(2));
    expect(details.playerById(player(1))!.isGoalkeeper, isTrue);
    // Time 2 não fica com 2 goleiros.
    expect(details.playerById(player(4))!.isGoalkeeper, isFalse);
  });

  test('do mesmo time não troca', () async {
    final notifier = await loaded();

    expect(await notifier.swapPlayers(player(2), player(1)), isFalse);

    final details = notifier.state.details!;
    expect(details.playerById(player(1))!.isGoalkeeper, isTrue);
    expect(details.playerById(player(2))!.teamId, team(1));
  });

  test('voltar etapa: Times → Sorteio (goleiros ficam) → Presença', () async {
    final notifier = await loaded();
    final keepers = notifier.state.details!.players
        .where((p) => p.isGoalkeeper)
        .map((p) => p.playerId)
        .toSet();

    expect(await notifier.stepBack(), isTrue);
    var details = notifier.state.details!;
    expect(details.status, ChampionshipStatus.teamDraw);
    expect(details.isDrawStage, isTrue);
    expect(details.players.every((p) => p.teamId == null), isTrue);
    expect(
      details.players.where((p) => p.isGoalkeeper).map((p) => p.playerId),
      unorderedEquals(keepers),
    );

    expect(await notifier.stepBack(), isTrue);
    details = notifier.state.details!;
    expect(details.status, ChampionshipStatus.acceptation);
  });

  test('sorteio com os métodos da partida e goleiros marcados antes', () async {
    final notifier = await loaded();
    await notifier.stepBack(); // volta para o Sorteio
    final first = notifier.state.details!.confirmedPlayers.first;
    expect(await notifier.setPlayerGoalkeeper(first.playerId, true), isTrue);
    expect(notifier.state.details!.playerById(first.playerId)!.isGoalkeeper,
        isTrue);

    final manual = await notifier.drawTeamOptions(
        teamCount: 3, strategyType: 1, includeGoalkeepers: true);
    expect(
        manual!.options.single.teams.every((t) => t.playerIds.isEmpty), isTrue);

    final draw = await notifier.drawTeamOptions(
        teamCount: 3, strategyType: 3, includeGoalkeepers: true);
    final option = draw!.options.first;
    expect(option.teams, hasLength(3));
    expect(
        await notifier
            .defineTeams(DefineChampionshipTeams(teams: option.teams)),
        isTrue);
    expect(notifier.state.details!.isTeamsStage, isTrue);
  });
}

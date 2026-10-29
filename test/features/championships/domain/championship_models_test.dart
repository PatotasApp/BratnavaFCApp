import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/championships/data/datasources/championship_mock_datasource.dart';
import 'package:patotas_app/features/championships/domain/entities/championship_enums.dart';
import 'package:patotas_app/features/championships/domain/entities/championship_models.dart';
import 'package:patotas_app/features/championships/domain/entities/championship_rules.dart';
import 'package:patotas_app/features/championships/presentation/championship_ui_text.dart';

void main() {
  test('regras preservam enums numéricos no round-trip JSON', () {
    final rules = ChampionshipRules.defaults().copyWith(
      historyMode: ChampionshipHistoryMode.separateGames,
      resultMode: ChampionshipResultMode.perGame,
      format: ChampionshipFormat.roundRobinWithFinal,
      roundRobinTurns: 2,
      winnerStays: const WinnerStaysRules(
        consecutiveWinsLimit: 2,
        tieRule: WinnerStaysTieRule.penaltyShootout,
      ),
    );

    final json = rules.toJson();
    final parsed = ChampionshipRules.fromJson(json);

    expect(json['historyMode'], 2);
    expect(json['resultMode'], 1);
    expect(json['format'], 4);
    expect((json['winnerStays'] as Map)['tieRule'], 3);
    expect(parsed.format, ChampionshipFormat.roundRobinWithFinal);
    expect(parsed.standings.tiebreakers, [
      ChampionshipTiebreakerCriteria.points,
      ChampionshipTiebreakerCriteria.goalDifference,
      ChampionshipTiebreakerCriteria.goalsFor,
      ChampionshipTiebreakerCriteria.headToHead,
      ChampionshipTiebreakerCriteria.externalDecision,
    ]);
  });

  test('upsert converte data local para UTC e recupera o mesmo instante', () {
    final instant = DateTime.parse('2026-10-27T18:30:00-03:00');
    final input = ChampionshipUpsert(
      name: 'Copa',
      playedAt: instant,
      placeName: 'Arena',
      rules: ChampionshipRules.defaults(),
    );

    final json = input.toJson();
    final parsed = ChampionshipUpsert.fromJson(json);

    expect(json['playedAt'], '2026-10-27T21:30:00.000Z');
    expect(parsed.playedAt.toUtc(), instant.toUtc());
  });

  test('mock oferece um campeonato em cada status do contrato', () async {
    final datasource = ChampionshipMockDataSource();

    final summaries = await datasource.fetchAll('group');

    expect(summaries, hasLength(ChampionshipStatus.values.length));
    expect(summaries.map((item) => item.status).toSet(),
        ChampionshipStatus.values.toSet());
  });

  test('InviteResponse segue os valores 1, 2 e 3 do contrato v2', () {
    expect(ChampionshipInviteResponse.none.value, 1);
    expect(ChampionshipInviteResponse.rejected.value, 2);
    expect(ChampionshipInviteResponse.accepted.value, 3);
  });

  test('detalhe aceita myInviteResponse nulo no contrato v3', () async {
    final datasource = ChampionshipMockDataSource();
    final source = await datasource.fetchById('group', 'championship-0');
    final json = source.toJson()..['myInviteResponse'] = null;

    final parsed = ChampionshipDetails.fromJson(json);

    expect(parsed.myInviteResponse, isNull);
  });

  test('validação rejeita resultado por jogo sem histórico separado', () {
    final rules = ChampionshipRules.defaults().copyWith(
      historyMode: ChampionshipHistoryMode.consolidated,
      resultMode: ChampionshipResultMode.perGame,
    );

    expect(
      rules.validate(),
      contains('Resultado por jogo exige histórico em jogos separados.'),
    );
  });

  test('validação exige Pontos como 1º desempate (v6)', () {
    final defaults = ChampionshipRules.defaults();
    final rules = defaults.copyWith(
      standings: ChampionshipStandingsRules(
        mode: defaults.standings.mode,
        winPoints: 3,
        drawPoints: 1,
        tiebreakers: const [
          ChampionshipTiebreakerCriteria.goalDifference,
          ChampionshipTiebreakerCriteria.points,
        ],
      ),
    );

    expect(rules.validate(),
        contains('Pontos tem de ser o 1º critério de desempate.'));
    expect(defaults.validate(), isEmpty);
  });

  test('resumo traduz regras em linguagem simples', () {
    expect(
      championshipRulesSummary(ChampionshipRules.defaults()),
      'Conta como uma única partida · 1º vitória, 2º empate, 3º derrota · '
      '1 MVP do campeonato',
    );
  });
}

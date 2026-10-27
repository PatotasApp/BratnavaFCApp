import '../domain/entities/championship_enums.dart';
import '../domain/entities/championship_rules.dart';

String championshipStatusLabel(ChampionshipStatus status) => switch (status) {
      ChampionshipStatus.created => 'Criado',
      ChampionshipStatus.acceptation => 'Presença',
      ChampionshipStatus.teamDraw => 'Times definidos',
      ChampionshipStatus.inProgress => 'Em andamento',
      ChampionshipStatus.postGame => 'Pós-campeonato',
      ChampionshipStatus.finalized => 'Finalizado',
      ChampionshipStatus.cancelled => 'Cancelado',
    };

String championshipFormatLabel(ChampionshipFormat format) => switch (format) {
      ChampionshipFormat.roundRobin => 'Todos contra todos',
      ChampionshipFormat.winnerStays => 'Fica quem ganha',
      ChampionshipFormat.roundRobinWithFinal => 'Todos contra todos + final',
    };

String placementResultLabel(PlacementResult result) => switch (result) {
      PlacementResult.win => 'vitória',
      PlacementResult.draw => 'empate',
      PlacementResult.loss => 'derrota',
      PlacementResult.none => 'sem resultado',
    };

String championshipRulesSummary(ChampionshipRules rules) {
  final history = switch (rules.historyMode) {
    ChampionshipHistoryMode.consolidated => 'Conta como 1 partida',
    ChampionshipHistoryMode.separateGames => 'Cada jogo conta separadamente',
    ChampionshipHistoryMode.championshipOnly => 'Aparece somente no campeonato',
  };
  final result = switch (rules.resultMode) {
    ChampionshipResultMode.perGame => 'Resultado definido por jogo',
    ChampionshipResultMode.placement => rules.placementResults
        .take(3)
        .toList()
        .asMap()
        .entries
        .map(
            (entry) => '${entry.key + 1}º ${placementResultLabel(entry.value)}')
        .join(', '),
    ChampionshipResultMode.winForAll => 'Vitória para todos',
    ChampionshipResultMode.presenceOnly => 'Conta somente presença',
  };
  final mvp = switch (rules.mvpMode) {
    ChampionshipMvpMode.perGame => 'MVP por jogo',
    ChampionshipMvpMode.perChampionship => '1 MVP do campeonato',
    ChampionshipMvpMode.none => 'Sem votação de MVP',
  };
  return '$history · $result · $mvp';
}

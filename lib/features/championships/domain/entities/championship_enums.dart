enum ChampionshipStatus {
  created(0),
  acceptation(1),
  teamDraw(2),
  inProgress(3),
  postGame(4),
  finalized(5),
  cancelled(6);

  const ChampionshipStatus(this.value);
  final int value;
}

enum ChampionshipHistoryMode {
  consolidated(1),
  separateGames(2),
  championshipOnly(3);

  const ChampionshipHistoryMode(this.value);
  final int value;
}

enum ChampionshipResultMode {
  perGame(1),
  placement(2),
  winForAll(3),
  presenceOnly(4);

  const ChampionshipResultMode(this.value);
  final int value;
}

enum PlacementResult {
  win(1),
  draw(2),
  loss(3),
  none(4);

  const PlacementResult(this.value);
  final int value;
}

enum ChampionshipMvpMode {
  perGame(1),
  perChampionship(2),
  none(3);

  const ChampionshipMvpMode(this.value);
  final int value;
}

enum ChampionshipFormat {
  roundRobin(1),
  winnerStays(2),
  roundRobinWithFinal(4);

  const ChampionshipFormat(this.value);
  final int value;
}

enum WinnerStaysTieRule {
  bothLeave(1),
  longestOnFieldLeaves(2),
  penaltyShootout(3);

  const WinnerStaysTieRule(this.value);
  final int value;
}

enum ChampionshipStandingMode {
  totalPoints(1),
  pointsPerGame(2);

  const ChampionshipStandingMode(this.value);
  final int value;
}

enum ChampionshipTiebreakerCriteria {
  points(1),
  goalDifference(2),
  goalsFor(3),
  headToHead(4),
  externalDecision(5);

  const ChampionshipTiebreakerCriteria(this.value);
  final int value;
}

enum WinnerStaysLimitRule {
  winnerLeaves(1),
  bothLeave(2);

  const WinnerStaysLimitRule(this.value);
  final int value;
}

enum ChampionshipGameStatus {
  inProgress(1),
  finished(2);

  const ChampionshipGameStatus(this.value);
  final int value;
}

enum ChampionshipInviteResponse {
  none(1),
  rejected(2),
  accepted(3);

  const ChampionshipInviteResponse(this.value);
  final int value;
}

T enumByValue<T extends Enum>(Iterable<T> values, int value) {
  for (final item in values) {
    final dynamic candidate = item;
    if (candidate.value == value) return item;
  }
  throw FormatException('Valor $value inválido para $T.');
}

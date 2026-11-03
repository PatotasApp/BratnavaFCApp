import 'entities/team_builder_models.dart';

const teamBuilderMaxPlayers = 5;

/// Período escolhido nos chips: temporada, desde uma data ou últimos N jogos.
class TeamBuilderPeriod {
  final int? season;
  final DateTime? since;
  final int? lastMatches;

  const TeamBuilderPeriod.season(int this.season)
      : since = null,
        lastMatches = null;
  const TeamBuilderPeriod.since(DateTime this.since)
      : season = null,
        lastMatches = null;
  const TeamBuilderPeriod.last(int this.lastMatches)
      : season = null,
        since = null;

  TeamBuilderFilter toFilter({required bool includeChampionship}) =>
      TeamBuilderFilter(
        season: season,
        from: since,
        lastMatches: lastMatches,
        includeChampionship: includeChampionship,
      );

  String get label {
    if (season != null) return 'Temporada $season';
    if (since != null) return 'Desde ${ddmm(since!)}';
    return 'Últimos $lastMatches jogos';
  }
}

String ddmm(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '';
  if (parts.length == 1) {
    final p = parts.first;
    return p.substring(0, p.length < 2 ? p.length : 2).toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

String verdictOf(int pct) {
  if (pct >= 70) return 'Time afiado';
  if (pct >= 55) return 'Boa química';
  if (pct >= 45) return 'Equilibrado';
  if (pct >= 30) return 'Ainda se acertando';
  return 'Não engrenou (ainda)';
}

String resultWord(int result) =>
    result > 0 ? 'vitória' : (result == 0 ? 'empate' : 'derrota');

String resultLetter(int result) => result > 0 ? 'V' : (result == 0 ? 'E' : 'D');

/// "3 vitórias seguidas", "1 empate seguido"...
String streakText(Streak s) {
  final plural = s.count > 1;
  final word = s.result > 0
      ? (plural ? 'vitórias' : 'vitória')
      : s.result == 0
          ? (plural ? 'empates' : 'empate')
          : (plural ? 'derrotas' : 'derrota');
  final following = s.result == 0
      ? (plural ? 'seguidos' : 'seguido')
      : (plural ? 'seguidas' : 'seguida');
  return '${s.count} $word $following';
}

/// 2,5 (vírgula decimal, uma casa).
String oneDecimal(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

/// "Caio, Pagel e Mozart".
String joinNames(List<String> names) {
  if (names.length <= 1) return names.join();
  return '${names.sublist(0, names.length - 1).join(', ')} e ${names.last}';
}

/// Quebra "texto **destaque** texto"; os pedaços ímpares são destaque.
List<({String text, bool bold})> boldParts(String text) {
  final parts = text.split('**');
  return [
    for (var i = 0; i < parts.length; i++)
      if (parts[i].isNotEmpty) (text: parts[i], bold: i.isOdd),
  ];
}

/// Pode entrar na seleção? Máximo de 5 e um goleiro só.
bool canAddPlayer(List<TeamBuilderPlayer> selected, TeamBuilderPlayer p) {
  if (selected.any((s) => s.id == p.id)) return false;
  if (selected.length >= teamBuilderMaxPlayers) return false;
  if (p.isGoalkeeper && selected.any((s) => s.isGoalkeeper)) return false;
  return true;
}

/// Vaga no campo: jogador ou vaga livre, com a posição em fração (x, y).
class PitchSlot {
  final TeamBuilderPlayer? player;
  final double x;
  final double y;
  final bool goalkeeper;
  const PitchSlot(this.player, this.x, this.y, {this.goalkeeper = false});
}

const _outfield = <int, List<(double, double)>>{
  0: [],
  1: [(.50, .40)],
  2: [(.32, .44), (.68, .44)],
  3: [(.50, .26), (.26, .52), (.74, .52)],
  4: [(.30, .26), (.70, .26), (.24, .54), (.76, .54)],
};

/// Goleiro embaixo; com [withEmpty], mostra a próxima vaga livre (e a do goleiro).
List<PitchSlot> pitchSlots(List<TeamBuilderPlayer> players,
    {required bool withEmpty}) {
  TeamBuilderPlayer? gk;
  for (final p in players) {
    if (p.isGoalkeeper) {
      gk = p;
      break;
    }
  }
  final field = players.where((p) => p != gk).toList();
  final room = withEmpty && players.length < teamBuilderMaxPlayers;
  final extra = room && field.length < 4 ? 1 : 0;
  final pos = _outfield[(field.length + extra).clamp(0, 4)]!;
  return [
    for (var i = 0; i < field.length; i++)
      PitchSlot(field[i], pos[i].$1, pos[i].$2),
    if (extra == 1) PitchSlot(null, pos[field.length].$1, pos[field.length].$2),
    if (gk != null)
      PitchSlot(gk, .50, .82, goalkeeper: true)
    else if (room)
      const PitchSlot(null, .50, .82, goalkeeper: true),
  ];
}

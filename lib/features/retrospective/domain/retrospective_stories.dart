import 'entities/player_retrospective.dart';

// Textos e regras de exibição da retrospectiva (protótipo aprovado em 02/11/2026).
// Espelho de src/domains/retrospective/retrospective.ts do site.

const retroMeses = [
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez'
];

class RetroProfile {
  final String title;
  final String tagline;
  const RetroProfile(this.title, this.tagline);
}

const retroProfiles = <String, RetroProfile>{
  'fiel': RetroProfile('O Fiel', 'Fez chuva, fez frio, e você estava lá.'),
  'matador':
      RetroProfile('O Matador', 'Mais gols por jogo que quase todo mundo.'),
  'garcom': RetroProfile('O Garçom', 'Seu passe valeu tanto quanto um gol.'),
  'pequente':
      RetroProfile('O Pé-quente', 'Time com você em campo costuma ganhar.'),
  'craque': RetroProfile('O Craque da Galera', 'A patota votou e reconheceu.'),
  'decisivo': RetroProfile(
      'O Decisivo', 'Quando o jogo apertou, a bola sobrou pra você.'),
  'paredao':
      RetroProfile('O Paredão', 'A temporada inteira debaixo das traves.'),
};

RetroProfile profileOf(PlayerRetrospective r) =>
    retroProfiles[r.profileKey] ?? retroProfiles['fiel']!;

enum StoryTheme { green, dark, blue, yellow, red }

enum StoryId {
  abertura,
  presenca,
  resultados,
  gols,
  assist,
  decisivo,
  parceria,
  rivais,
  marcos,
  mvp,
  golcontra,
  perfil,
  resumo
}

class StoryMeta {
  final StoryId id;
  final String name;
  final StoryTheme theme;
  const StoryMeta(this.id, this.name, this.theme);
}

const _all = [
  StoryMeta(StoryId.abertura, 'Abertura', StoryTheme.green),
  StoryMeta(StoryId.presenca, 'Presença', StoryTheme.dark),
  StoryMeta(StoryId.resultados, 'Resultados', StoryTheme.blue),
  StoryMeta(StoryId.gols, 'Gols', StoryTheme.green),
  StoryMeta(StoryId.assist, 'Assistências', StoryTheme.yellow),
  StoryMeta(StoryId.decisivo, 'Gols decisivos', StoryTheme.red),
  StoryMeta(StoryId.parceria, 'Parcerias', StoryTheme.dark),
  StoryMeta(StoryId.rivais, 'Rivalidades', StoryTheme.red),
  StoryMeta(StoryId.marcos, 'Seus marcos', StoryTheme.blue),
  StoryMeta(StoryId.mvp, 'MVP', StoryTheme.yellow),
  StoryMeta(StoryId.golcontra, 'Gol contra', StoryTheme.dark),
  StoryMeta(StoryId.perfil, 'Seu perfil', StoryTheme.green),
  StoryMeta(StoryId.resumo, 'Resumo', StoryTheme.dark),
];

/// Só os stories com dado para o jogador. Sem jogo no período, nenhum.
List<StoryMeta> storiesFor(PlayerRetrospective r) {
  if (r.games == 0) return const [];
  bool has(StoryId id) => switch (id) {
        StoryId.resultados => r.results > 0,
        StoryId.gols => r.goals > 0,
        StoryId.assist => r.assists > 0,
        StoryId.decisivo => r.openers + r.winningGoals > 0,
        StoryId.parceria => r.bestPartner != null || r.frequentPartner != null,
        StoryId.rivais => r.fregues != null || r.carrasco != null,
        StoryId.marcos => r.milestones.isNotEmpty,
        StoryId.mvp => r.mvps > 0 || r.mvpVotes > 0,
        StoryId.golcontra => r.ownGoals > 0,
        _ => true,
      };
  return _all.where((s) => has(s.id)).toList();
}

String plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';
String ord(int n, {bool fem = false}) => '$n${fem ? 'ª' : 'º'}';

/// "o maior da patota" / "4º da patota".
String rk(int n) => n == 1 ? 'o maior da patota' : '${ord(n)} da patota';

/// Começo de frase: "O maior da patota" / "O 4º da patota".
String rkSentence(int n) =>
    n == 1 ? 'O maior da patota' : 'O ${ord(n)} da patota';

String fmtNum(double n) {
  final s = (n * 100).round() / 100;
  final txt = s == s.roundToDouble() ? s.toStringAsFixed(0) : s.toString();
  return txt.replaceAll('.', ',');
}

int pct(int a, int b) => b == 0 ? 0 : (a / b * 100).round();

/// Posição só aparece quando ajuda: até a metade de cima de quem tem o mínimo de jogos.
String? topHalf(PlayerRetrospective r, int? rank) {
  final limit = ((r.ratedPlayers < 1 ? 1 : r.ratedPlayers) / 2).ceil();
  return rank != null && rank <= limit ? '${ord(rank)} da patota' : null;
}

/// dd/MM no horário de Brasília (UTC−3, sem horário de verão desde 2019).
String dayMonth(DateTime utc) {
  final d = utc.toUtc().subtract(const Duration(hours: 3));
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

String monthLabel(PlayerRetrospective r, int year, int month) {
  final years = r.months.map((m) => m.year).toSet();
  return years.length > 1
      ? '${retroMeses[month - 1]}/${year.toString().substring(2)}'
      : retroMeses[month - 1];
}

String recordText(int w, int d, int l) => '${w}V ${d}E ${l}D';

({String badge, String text}) milestoneText(
        String kind, int number, bool partial) =>
    switch (kind) {
      'first_goal' => (badge: ord(1), text: 'Fez o primeiro gol da temporada'),
      'last_goal' => (
          badge: ord(number),
          text: partial
              ? 'Fez o gol mais recente da temporada'
              : 'Fez o último gol registrado da temporada'
        ),
      'goal_century' => (
          badge: ord(number),
          text: 'Fez o gol número $number da patota'
        ),
      'first_assist' => (
          badge: ord(1, fem: true),
          text: 'Deu a primeira assistência da temporada'
        ),
      'assist_century' => (
          badge: ord(number, fem: true),
          text: 'Deu a assistência número $number da patota'
        ),
      _ => (badge: ord(number), text: ''),
    };

class ProfileData {
  final String heroValue;
  final String heroLabel;
  final List<(String, String)> rows;
  const ProfileData(this.heroValue, this.heroLabel, this.rows);
}

/// Os números que explicam o perfil: o dado principal, a taxa e a posição na patota.
ProfileData profileData(PlayerRetrospective r) {
  final jogos = plural(r.games, 'jogo', 'jogos');
  final lances = r.openers + r.winningGoals;
  List<(String, String)> rows(List<(String, Object?)> list) => [
        for (final (l, v) in list)
          if (v != null && v != '') (l, v.toString())
      ];

  return switch (r.profileKey) {
    'matador' => ProfileData(
        fmtNum(r.goalsPerGame),
        'gols por jogo',
        rows([
          ('Gols', '${r.goals} em $jogos'),
          ('Em gols por jogo', topHalf(r, r.goalsPerGameRank)),
          (
            'Melhor noite',
            r.bestGoalNight == null
                ? null
                : plural(r.bestGoalNight!.count, 'gol', 'gols')
          ),
        ])),
    'garcom' => ProfileData(
        fmtNum(r.assistsPerGame),
        'assistências por jogo',
        rows([
          ('Assistências', '${r.assists} em $jogos'),
          ('Em assistências por jogo', topHalf(r, r.assistsPerGameRank)),
          ('Mais recebeu seus passes', r.mostAssistedTo?.name),
        ])),
    'pequente' => ProfileData(
        '${r.aproveitamento}%',
        'de aproveitamento',
        rows([
          ('Vitórias', '${r.wins} em $jogos'),
          ('No ranking', topHalf(r, r.resultsRank)),
          ('Mais vitórias seguidas', r.longestWinStreak),
        ])),
    'craque' => ProfileData(
        '${r.mvps}',
        r.mvps == 1 ? 'vez MVP' : 'vezes MVP',
        rows([
          ('Eleito em', '${pct(r.mvps, r.games)}% dos seus jogos'),
          ('Votos recebidos', r.mvpVotes),
          ('No ranking de MVP', topHalf(r, r.mvpRank)),
        ])),
    'decisivo' => ProfileData(
        '$lances',
        lances == 1 ? 'lance decisivo' : 'lances decisivos',
        rows([
          ('Abriu o placar', plural(r.openers, 'vez', 'vezes')),
          ('Gols da vitória', r.winningGoals),
          (
            'Frequência',
            lances == 0
                ? null
                : '1 a cada ${fmtNum((r.games / lances * 10).round() / 10)} jogos'
          ),
          ('Nesse quesito', topHalf(r, r.decisivePerGameRank)),
        ])),
    'paredao' => ProfileData(
        '${r.goalkeeperGames}',
        'jogos no gol',
        rows([
          (
            'Isso representa',
            '${pct(r.goalkeeperGames, r.totalGames)}% da temporada'
          ),
          ('Aproveitamento', '${r.aproveitamento}%'),
          ('Votos de MVP', r.mvpVotes),
        ])),
    _ => ProfileData(
        '${r.presencePercent}%',
        'dos jogos da patota',
        rows([
          ('Você foi a', '${r.games} de ${r.totalGames} jogos'),
          (
            'Maior sequência sem faltar',
            plural(r.longestPresenceStreak, 'jogo', 'jogos')
          ),
          ('No ranking de presença', topHalf(r, r.presenceRank)),
        ])),
  };
}

/// Dupla para o resumo: a de ouro, senão quem mais jogou do lado.
String summaryPartner(PlayerRetrospective r) =>
    r.bestPartner?.name ?? r.frequentPartner?.name ?? '—';

/// Nome do arquivo da imagem compartilhada.
String storyFileName(PlayerRetrospective r, StoryMeta s) {
  String slug(String v) => v
      .toLowerCase()
      .replaceAll(RegExp('[áàâã]'), 'a')
      .replaceAll(RegExp('[éê]'), 'e')
      .replaceAll('í', 'i')
      .replaceAll(RegExp('[óôõ]'), 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return 'retrospectiva-${slug(r.period.label)}-${slug(r.player.shortName)}-${s.id.name}';
}

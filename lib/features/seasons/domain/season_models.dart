/// Temporadas da patota (docs/temporadas/TEMPORADAS.md no repo da API).
///
/// A partida pertence à temporada pela data do jogo. A pré-temporada conta na
/// carreira, mas sai dos filtros e títulos do ano.
class Season {
  final String id;
  final int year;
  final int number;
  final String? name;
  final String displayName;
  final DateTime startsAt;
  final DateTime? endsAt;
  final bool isPreSeason;
  final bool isOpen;
  final bool isCurrent;
  final int matches;
  final int championships;
  final DateTime? closedAt;
  final String? closedByName;

  const Season({
    required this.id,
    required this.year,
    required this.number,
    this.name,
    required this.displayName,
    required this.startsAt,
    this.endsAt,
    required this.isPreSeason,
    required this.isOpen,
    required this.isCurrent,
    required this.matches,
    required this.championships,
    this.closedAt,
    this.closedByName,
  });

  /// Já acabou (o corte passou): tem retrospectiva.
  bool get hasEnded => endsAt != null && !endsAt!.isAfter(DateTime.now());

  bool contains(DateTime playedAt) =>
      !playedAt.isBefore(startsAt) && (endsAt == null || playedAt.isBefore(endsAt!));

  factory Season.fromJson(Map<String, dynamic> json) => Season(
        id: json['id'] as String,
        year: (json['year'] as num).toInt(),
        number: (json['number'] as num).toInt(),
        name: json['name'] as String?,
        displayName: json['displayName'] as String? ?? '',
        startsAt: DateTime.parse(json['startsAt'] as String),
        endsAt: _date(json['endsAt']),
        isPreSeason: json['isPreSeason'] as bool? ?? false,
        isOpen: json['isOpen'] as bool? ?? false,
        isCurrent: json['isCurrent'] as bool? ?? false,
        matches: (json['matches'] as num?)?.toInt() ?? 0,
        championships: (json['championships'] as num?)?.toInt() ?? 0,
        closedAt: _date(json['closedAt']),
        closedByName: json['closedByName'] as String?,
      );
}

class SeasonsOverview {
  /// Da mais antiga para a mais nova.
  final List<Season> seasons;
  final String? currentSeasonId;

  /// Algum admin já fechou temporada: o ano novo não vira sozinho.
  final bool manualMode;
  final bool canUndoClose;

  const SeasonsOverview({
    required this.seasons,
    this.currentSeasonId,
    required this.manualMode,
    required this.canUndoClose,
  });

  Season? get current =>
      seasons.where((s) => s.id == currentSeasonId).firstOrNull;

  Season? get open => seasons.where((s) => s.isOpen).firstOrNull;

  /// Temporada aberta de um ano que já passou: aviso para o admin abrir a próxima.
  bool get openSeasonFromPastYear {
    final o = open;
    return o != null && manualMode && o.year < DateTime.now().year;
  }

  factory SeasonsOverview.fromJson(Map<String, dynamic> json) => SeasonsOverview(
        seasons: _list(json['seasons'], Season.fromJson),
        currentSeasonId: json['currentSeasonId'] as String?,
        manualMode: json['manualMode'] as bool? ?? false,
        canUndoClose: json['canUndoClose'] as bool? ?? false,
      );
}

class SeasonClosePreview {
  final String closingDisplayName;
  final DateTime closingStartsAt;
  final DateTime cutAt;
  final int closingMatches;
  final int closingChampionships;
  final int nextYear;
  final String nextDefaultName;
  final int movedMatches;
  final int movedChampionships;

  const SeasonClosePreview({
    required this.closingDisplayName,
    required this.closingStartsAt,
    required this.cutAt,
    required this.closingMatches,
    required this.closingChampionships,
    required this.nextYear,
    required this.nextDefaultName,
    required this.movedMatches,
    required this.movedChampionships,
  });

  factory SeasonClosePreview.fromJson(Map<String, dynamic> json) => SeasonClosePreview(
        closingDisplayName: json['closingDisplayName'] as String? ?? '',
        closingStartsAt: DateTime.parse(json['closingStartsAt'] as String),
        cutAt: DateTime.parse(json['cutAt'] as String),
        closingMatches: (json['closingMatches'] as num?)?.toInt() ?? 0,
        closingChampionships: (json['closingChampionships'] as num?)?.toInt() ?? 0,
        nextYear: (json['nextYear'] as num).toInt(),
        nextDefaultName: json['nextDefaultName'] as String? ?? '',
        movedMatches: (json['movedMatches'] as num?)?.toInt() ?? 0,
        movedChampionships: (json['movedChampionships'] as num?)?.toInt() ?? 0,
      );
}

/// Retrospectiva: totais, títulos e a classificação real de cada categoria.
class SeasonSummary {
  final Season season;
  final int matches;
  final int championships;
  final int goals;
  final int players;
  final bool titlesSealed;
  final List<SeasonRanking> rankings;

  const SeasonSummary({
    required this.season,
    required this.matches,
    required this.championships,
    required this.goals,
    required this.players,
    required this.titlesSealed,
    required this.rankings,
  });

  factory SeasonSummary.fromJson(Map<String, dynamic> json) => SeasonSummary(
        season: Season.fromJson((json['season'] as Map).cast<String, dynamic>()),
        matches: (json['matches'] as num?)?.toInt() ?? 0,
        championships: (json['championships'] as num?)?.toInt() ?? 0,
        goals: (json['goals'] as num?)?.toInt() ?? 0,
        players: (json['players'] as num?)?.toInt() ?? 0,
        titlesSealed: json['titlesSealed'] as bool? ?? false,
        rankings: _list(json['rankings'], SeasonRanking.fromJson),
      );
}

class SeasonRanking {
  final String category;
  final String name;
  final String icon;
  final int minGames;
  final List<SeasonRankingRow> rows;

  const SeasonRanking({
    required this.category,
    required this.name,
    required this.icon,
    required this.minGames,
    required this.rows,
  });

  String format(int value) => category == 'Aproveitamento' ? '$value%' : '$value';

  factory SeasonRanking.fromJson(Map<String, dynamic> json) => SeasonRanking(
        category: json['category'] as String? ?? '',
        name: json['name'] as String? ?? '',
        icon: json['icon'] as String? ?? '',
        minGames: (json['minGames'] as num?)?.toInt() ?? 0,
        rows: _list(json['rows'], SeasonRankingRow.fromJson),
      );
}

class SeasonRankingRow {
  /// Posição real: empatados dividem a posição (1, 2, 2, 4).
  final int position;
  final String playerId;
  final String playerName;
  final int value;
  final int games;
  final bool isGuest;

  const SeasonRankingRow({
    required this.position,
    required this.playerId,
    required this.playerName,
    required this.value,
    required this.games,
    required this.isGuest,
  });

  factory SeasonRankingRow.fromJson(Map<String, dynamic> json) => SeasonRankingRow(
        position: (json['position'] as num).toInt(),
        playerId: json['playerId'] as String,
        playerName: json['playerName'] as String? ?? '',
        value: (json['value'] as num?)?.toInt() ?? 0,
        games: (json['games'] as num?)?.toInt() ?? 0,
        isGuest: json['isGuest'] as bool? ?? false,
      );
}

/// O que o seletor de temporada escolheu. "Atual" acompanha a temporada atual.
sealed class SeasonSelection {
  const SeasonSelection();

  /// Valor estável para o seletor e para chaves de provider.
  String get key;

  static SeasonSelection parse(String key) {
    if (key.startsWith('season:')) return SeasonPick(key.substring(7));
    if (key.startsWith('year:')) {
      final parts = key.split(':');
      return YearPick(int.parse(parts[1]), includePreSeason: parts[2] == '1');
    }
    return key == 'all' ? const AllSeasons() : const CurrentSeason();
  }
}

class CurrentSeason extends SeasonSelection {
  const CurrentSeason();
  @override
  String get key => 'current';
}

class SeasonPick extends SeasonSelection {
  final String id;
  const SeasonPick(this.id);
  @override
  String get key => 'season:$id';
}

class YearPick extends SeasonSelection {
  final int year;
  final bool includePreSeason;
  const YearPick(this.year, {required this.includePreSeason});
  @override
  String get key => 'year:$year:${includePreSeason ? 1 : 0}';
}

class AllSeasons extends SeasonSelection {
  const AllSeasons();
  @override
  String get key => 'all';
}

extension SeasonSelectionX on SeasonSelection {
  /// Temporada concreta (atual ou escolhida); null para ano e "todas".
  Season? seasonIn(SeasonsOverview? overview) => switch (this) {
        CurrentSeason() => overview?.current,
        SeasonPick(:final id) => overview?.seasons.where((s) => s.id == id).firstOrNull,
        _ => null,
      };

  /// Parâmetros da API (visual-stats): vazio = tudo.
  Map<String, String> params(SeasonsOverview? overview) => switch (this) {
        YearPick(:final year, :final includePreSeason) => {
            'year': '$year',
            'includePreSeason': '$includePreSeason',
          },
        AllSeasons() => const {},
        _ => seasonIn(overview) == null ? const {} : {'seasonId': seasonIn(overview)!.id},
      };

  /// Filtro local pela data do jogo, igual ao da API.
  bool contains(SeasonsOverview? overview, DateTime playedAt) {
    if (overview == null) return true;
    return switch (this) {
      AllSeasons() => true,
      YearPick(:final year, :final includePreSeason) => overview.seasons.any((s) =>
          s.year == year && (includePreSeason || !s.isPreSeason) && s.contains(playedAt)),
      _ => seasonIn(overview)?.contains(playedAt) ?? true,
    };
  }

  String label(SeasonsOverview? overview) => switch (this) {
        AllSeasons() => 'Todas as temporadas',
        YearPick(:final year, :final includePreSeason) =>
          includePreSeason ? '$year (com pré-temporada)' : '$year',
        _ => seasonIn(overview)?.displayName ?? 'Temporada atual',
      };
}

DateTime? _date(dynamic value) => value is String ? DateTime.parse(value) : null;

List<T> _list<T>(dynamic value, T Function(Map<String, dynamic>) map) =>
    value is List ? value.whereType<Map>().map((e) => map(e.cast<String, dynamic>())).toList() : <T>[];

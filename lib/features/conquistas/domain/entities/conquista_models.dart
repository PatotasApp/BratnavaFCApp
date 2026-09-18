class ConquistaEtapa {
  final String nome;
  final String descricao;
  final int? meta;
  final bool desbloqueada;

  const ConquistaEtapa({
    required this.nome,
    required this.descricao,
    required this.meta,
    required this.desbloqueada,
  });

  factory ConquistaEtapa.fromJson(Map<String, dynamic> json) => ConquistaEtapa(
        nome: json['nome']?.toString() ?? '',
        descricao: json['descricao']?.toString() ?? '',
        meta: (json['meta'] as num?)?.toInt(),
        desbloqueada: json['desbloqueada'] == true,
      );
}

class Conquista {
  final String id;
  final String nome;
  final String descricao;
  final String categoria;
  final String icone;
  final String raridade;
  final double pctPatota;
  final bool desbloqueada;
  final int? count;
  final int? valor;
  final int? meta;
  final int? nivel;
  final int? totalNiveis;
  final String? proximoNome;
  final int? ano;
  final int? posicao;
  final List<ConquistaEtapa> etapas;

  const Conquista({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.categoria,
    required this.icone,
    required this.raridade,
    required this.pctPatota,
    required this.desbloqueada,
    this.count,
    this.valor,
    this.meta,
    this.nivel,
    this.totalNiveis,
    this.proximoNome,
    this.ano,
    this.posicao,
    this.etapas = const [],
  });

  factory Conquista.fromJson(Map<String, dynamic> json) => Conquista(
        id: json['id']?.toString() ?? '',
        nome: json['nome']?.toString() ?? '',
        descricao: json['descricao']?.toString() ?? '',
        categoria: json['categoria']?.toString() ?? '',
        icone: json['icone']?.toString() ?? '🏅',
        raridade: json['raridade']?.toString() ?? 'Comum',
        pctPatota: (json['pctPatota'] as num?)?.toDouble() ?? 0,
        desbloqueada: json['desbloqueada'] == true,
        count: (json['count'] as num?)?.toInt(),
        valor: (json['valor'] as num?)?.toInt(),
        meta: (json['meta'] as num?)?.toInt(),
        nivel: (json['nivel'] as num?)?.toInt(),
        totalNiveis: (json['totalNiveis'] as num?)?.toInt(),
        proximoNome: json['proximoNome']?.toString(),
        ano: (json['ano'] as num?)?.toInt(),
        posicao: (json['posicao'] as num?)?.toInt(),
        etapas: _list(json['etapas'], ConquistaEtapa.fromJson),
      );
}

class SeasonStanding {
  final String categoria;
  final String nome;
  final String icone;
  final int valor;
  final int posicao;
  final int total;
  final double percentil;
  final String raridade;

  const SeasonStanding({
    required this.categoria,
    required this.nome,
    required this.icone,
    required this.valor,
    required this.posicao,
    required this.total,
    required this.percentil,
    required this.raridade,
  });

  factory SeasonStanding.fromJson(Map<String, dynamic> json) => SeasonStanding(
        categoria: json['categoria']?.toString() ?? '',
        nome: json['nome']?.toString() ?? '',
        icone: json['icone']?.toString() ?? '🏅',
        valor: (json['valor'] as num?)?.toInt() ?? 0,
        posicao: (json['posicao'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        percentil: (json['percentil'] as num?)?.toDouble() ?? 0,
        raridade: json['raridade']?.toString() ?? 'Comum',
      );
}

class PlayerConquistas {
  final String playerId;
  final String? userId;
  final String playerName;
  final bool isGoalkeeper;
  final List<Conquista> marcos;
  final List<Conquista> eventos;
  final List<Conquista> titulos;
  final List<SeasonStanding> temporada;

  const PlayerConquistas({
    required this.playerId,
    required this.userId,
    required this.playerName,
    required this.isGoalkeeper,
    required this.marcos,
    required this.eventos,
    required this.titulos,
    required this.temporada,
  });

  int get totalDesbloqueadas =>
      marcos.where((item) => item.desbloqueada).length +
      eventos.where((item) => (item.count ?? 0) > 0).length +
      titulos.length;

  factory PlayerConquistas.fromJson(Map<String, dynamic> json) =>
      PlayerConquistas(
        playerId: json['playerId']?.toString() ?? '',
        userId: json['userId']?.toString(),
        playerName: json['playerName']?.toString() ?? '',
        isGoalkeeper: json['isGoalkeeper'] == true,
        marcos: _list(json['marcos'], Conquista.fromJson),
        eventos: _list(json['eventos'], Conquista.fromJson),
        titulos: _list(json['titulos'], Conquista.fromJson),
        temporada: _list(json['temporada'], SeasonStanding.fromJson),
      );
}

class GroupConquistas {
  final String groupId;
  final int season;
  final List<PlayerConquistas> players;

  const GroupConquistas({
    required this.groupId,
    required this.season,
    required this.players,
  });

  factory GroupConquistas.fromJson(Map<String, dynamic> json) =>
      GroupConquistas(
        groupId: json['groupId']?.toString() ?? '',
        season: (json['season'] as num?)?.toInt() ?? DateTime.now().year,
        players: _list(json['players'], PlayerConquistas.fromJson),
      );
}

class PatotaProfile {
  final String? groupId;
  final String groupName;
  final int games;
  final int goals;
  final int assists;
  final int mvps;
  final PlayerConquistas conquistas;

  const PatotaProfile({
    required this.groupId,
    required this.groupName,
    required this.games,
    required this.goals,
    required this.assists,
    required this.mvps,
    required this.conquistas,
  });

  factory PatotaProfile.fromJson(Map<String, dynamic> json) => PatotaProfile(
        groupId: json['groupId']?.toString(),
        groupName: json['groupName']?.toString() ?? '',
        games: (json['games'] as num?)?.toInt() ?? 0,
        goals: (json['goals'] as num?)?.toInt() ?? 0,
        assists: (json['assists'] as num?)?.toInt() ?? 0,
        mvps: (json['mvps'] as num?)?.toInt() ?? 0,
        conquistas: PlayerConquistas.fromJson(
          (json['conquistas'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
      );
}

class UserPublicProfile {
  final String userId;
  final String name;
  final String userName;
  final String? photoUrl;
  final int? age;
  final String? position;
  final int games;
  final int goals;
  final int assists;
  final int mvps;
  final List<Conquista> marcos;
  final List<Conquista> feitos;
  final List<Conquista> titulos;
  final List<Conquista> destaques;
  final List<PatotaProfile> patotas;

  const UserPublicProfile({
    required this.userId,
    required this.name,
    required this.userName,
    required this.photoUrl,
    required this.age,
    required this.position,
    required this.games,
    required this.goals,
    required this.assists,
    required this.mvps,
    required this.marcos,
    required this.feitos,
    required this.titulos,
    required this.destaques,
    required this.patotas,
  });

  factory UserPublicProfile.fromJson(Map<String, dynamic> json) =>
      UserPublicProfile(
        userId: json['userId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        userName: json['userName']?.toString() ?? '',
        photoUrl: json['photoUrl']?.toString(),
        age: (json['age'] as num?)?.toInt(),
        position: json['position']?.toString(),
        games: (json['games'] as num?)?.toInt() ?? 0,
        goals: (json['goals'] as num?)?.toInt() ?? 0,
        assists: (json['assists'] as num?)?.toInt() ?? 0,
        mvps: (json['mvps'] as num?)?.toInt() ?? 0,
        marcos: _list(json['marcos'], Conquista.fromJson),
        feitos: _list(json['feitos'], Conquista.fromJson),
        titulos: _list(json['titulos'], Conquista.fromJson),
        destaques: _list(json['destaques'], Conquista.fromJson),
        patotas: _list(json['patotas'], PatotaProfile.fromJson),
      );
}

class ProfilePrivacy {
  final String visibility;
  final bool showPatotaNames;
  final bool showZoeiraAchievements;

  const ProfilePrivacy({
    required this.visibility,
    required this.showPatotaNames,
    required this.showZoeiraAchievements,
  });

  factory ProfilePrivacy.fromJson(Map<String, dynamic> json) => ProfilePrivacy(
        visibility: json['visibility']?.toString() ?? 'AuthenticatedUsers',
        showPatotaNames: json['showPatotaNames'] != false,
        showZoeiraAchievements: json['showZoeiraAchievements'] == true,
      );

  Map<String, dynamic> toJson() => {
        'visibility': visibility,
        'showPatotaNames': showPatotaNames,
        'showZoeiraAchievements': showZoeiraAchievements,
      };

  ProfilePrivacy copyWith({
    String? visibility,
    bool? showPatotaNames,
    bool? showZoeiraAchievements,
  }) =>
      ProfilePrivacy(
        visibility: visibility ?? this.visibility,
        showPatotaNames: showPatotaNames ?? this.showPatotaNames,
        showZoeiraAchievements:
            showZoeiraAchievements ?? this.showZoeiraAchievements,
      );
}

List<T> _list<T>(dynamic value, T Function(Map<String, dynamic>) fromJson) {
  if (value is! List) return <T>[];
  return value
      .whereType<Map>()
      .map((item) => fromJson(item.cast<String, dynamic>()))
      .toList();
}

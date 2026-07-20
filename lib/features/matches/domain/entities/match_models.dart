import 'package:flutter/material.dart';
import '../../../../core/utils/date_utils.dart';

// ── Passo da partida ──────────────────────────────────────────────────────────

enum MatchStep {
  create, // sem partida / status 0
  accept, // status 1
  teams, // status 2
  playing, // status 3
  ended, // status 4
  post, // status 5
  done; // status 6

  static MatchStep fromStatus(int status) {
    switch (status) {
      case 1:
        return accept;
      case 2:
        return teams;
      case 3:
        return playing;
      case 4:
        return ended;
      case 5:
        return post;
      case 6:
        return done;
      default:
        return create;
    }
  }

  static MatchStep fromKey(String key) {
    switch (key) {
      case 'accept':
        return accept;
      case 'teams':
        return teams;
      case 'playing':
        return playing;
      case 'ended':
        return ended;
      case 'post':
        return post;
      case 'done':
        return done;
      default:
        return create;
    }
  }

  int get stepNumber => MatchStep.values.indexOf(this) + 1;

  String get label {
    switch (this) {
      case create:
        return 'Criar';
      case accept:
        return 'Aceitação';
      case teams:
        return 'Formação';
      case playing:
        return 'Em jogo';
      case ended:
        return 'Encerramento';
      case post:
        return 'Pós-jogo';
      case done:
        return 'Finalizada';
    }
  }
}

// ── Resposta ao convite ───────────────────────────────────────────────────────

String matchStepLabel(String? stepOrStatus) {
  final raw = stepOrStatus?.trim() ?? '';
  if (raw.isEmpty) return '';
  final key = raw
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_-]+'), '')
      .replaceAll('ç', 'c')
      .replaceAll('ã', 'a')
      .replaceAll('á', 'a')
      .replaceAll('â', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u');

  return switch (key) {
    'create' || 'created' || 'criacao' || 'criar' => 'Criação',
    'accept' || 'acceptation' || 'acceptance' || 'aceitacao' => 'Aceitação',
    'teams' || 'matchmaking' || 'formacao' => 'Times',
    'playing' || 'live' || 'started' || 'emjogo' => 'Em jogo',
    'ended' || 'encerrada' || 'encerramento' => 'Encerrada',
    'post' || 'postgame' || 'posjogo' => 'Pós-jogo',
    'done' || 'finished' || 'finalized' || 'finalizada' => 'Finalizada',
    _ => raw,
  };
}

enum InviteResponse { pending, accepted, declined }

// ── Cor do time ───────────────────────────────────────────────────────────────

class TeamColorInfo {
  final String id;
  final String name;
  final String hexValue;

  const TeamColorInfo(
      {required this.id, required this.name, required this.hexValue});

  Color get color {
    final hex = hexValue.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  factory TeamColorInfo.fromJson(Map<String, dynamic> j) => TeamColorInfo(
        id: (j['id'] ?? j['Id'] ?? '').toString(),
        name: j['name'] as String? ?? j['Name'] as String? ?? '',
        hexValue:
            j['hexValue'] as String? ?? j['HexValue'] as String? ?? '#e2e8f0',
      );
}

// ── Header resumido de uma partida (endpoint /upcoming) ──────────────────────

class MatchHeaderDto {
  final String matchId;
  final String groupId;
  final DateTime playedAt;
  final String placeName;
  final int status;
  final String statusName;
  final String stepKey;
  final bool canRewind;
  final int? teamAGoals;
  final int? teamBGoals;
  final String? linkedPollId;
  final DateTime? actualStartTime;

  const MatchHeaderDto({
    required this.matchId,
    required this.groupId,
    required this.playedAt,
    required this.placeName,
    required this.status,
    required this.statusName,
    required this.stepKey,
    required this.canRewind,
    this.teamAGoals,
    this.teamBGoals,
    this.linkedPollId,
    this.actualStartTime,
  });

  MatchStep get step => MatchStep.fromKey(stepKey);

  factory MatchHeaderDto.fromJson(Map<String, dynamic> j) => MatchHeaderDto(
        matchId: (j['matchId'] ?? j['MatchId'] ?? '').toString(),
        groupId: (j['groupId'] ?? j['GroupId'] ?? '').toString(),
        playedAt: parseApiDate((j['playedAt'] ?? j['PlayedAt'])?.toString()),
        placeName: j['placeName'] as String? ?? j['PlaceName'] as String? ?? '',
        status: j['status'] as int? ?? j['Status'] as int? ?? 0,
        statusName:
            j['statusName'] as String? ?? j['StatusName'] as String? ?? '',
        stepKey: j['stepKey'] as String? ?? j['StepKey'] as String? ?? 'create',
        canRewind: j['canRewind'] as bool? ?? j['CanRewind'] as bool? ?? false,
        teamAGoals: j['teamAGoals'] as int? ?? j['TeamAGoals'] as int?,
        teamBGoals: j['teamBGoals'] as int? ?? j['TeamBGoals'] as int?,
        linkedPollId: (j['linkedPollId'] ?? j['LinkedPollId'])?.toString(),
        actualStartTime: parseApiDateOrNull(
            (j['actualStartTime'] ?? j['ActualStartTime'])?.toString()),
      );
}

// ── Jogador na partida ────────────────────────────────────────────────────────

class MatchPlayerInfo {
  final String matchPlayerId;
  final String playerId;
  final String playerName;
  final bool isGoalkeeper;
  final bool isGuest;
  final int team; // 0=não atribuído, 1=timeA, 2=timeB
  final InviteResponse inviteResponse;
  final String? inviteRespondedAt;

  /// Ausência ativa no momento da partida (null = sem ausência).
  final int? absenceType;
  final String? absenceDescription;

  /// Jogador confirmou mas não apareceu. Excluído de stats, MVP e gols.
  final bool didNotPlay;

  /// É MVP desta partida (só preenchido no histórico/pós-jogo).
  final bool isMvp;

  const MatchPlayerInfo({
    required this.matchPlayerId,
    required this.playerId,
    required this.playerName,
    required this.isGoalkeeper,
    required this.isGuest,
    required this.team,
    required this.inviteResponse,
    this.inviteRespondedAt,
    this.absenceType,
    this.absenceDescription,
    this.didNotPlay = false,
    this.isMvp = false,
  });

  static InviteResponse _parseInvite(dynamic v) {
    final n = v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    if (n == 3) return InviteResponse.accepted; // backend: Accepted = 3
    if (n == 2) return InviteResponse.declined; // backend: Rejected = 2
    return InviteResponse.pending; // backend: None = 1
  }

  factory MatchPlayerInfo.fromJson(Map<String, dynamic> j) => MatchPlayerInfo(
        matchPlayerId:
            (j['matchPlayerId'] ?? j['MatchPlayerId'] ?? '').toString(),
        playerId: (j['playerId'] ?? j['PlayerId'] ?? '').toString(),
        playerName: j['playerName'] as String? ??
            j['PlayerName'] as String? ??
            j['name'] as String? ??
            j['Name'] as String? ??
            '',
        isGoalkeeper:
            j['isGoalkeeper'] as bool? ?? j['IsGoalkeeper'] as bool? ?? false,
        isGuest: j['isGuest'] as bool? ?? j['IsGuest'] as bool? ?? false,
        team: j['team'] as int? ?? j['Team'] as int? ?? 0,
        inviteResponse:
            _parseInvite(j['inviteResponse'] ?? j['InviteResponse']),
        inviteRespondedAt: (j['inviteRespondedAt'] ?? j['InviteRespondedAt'])
            as String?,
        absenceType: j['absenceType'] as int? ?? j['AbsenceType'] as int?,
        absenceDescription: j['absenceDescription'] as String? ??
            j['AbsenceDescription'] as String?,
        didNotPlay:
            j['didNotPlay'] as bool? ?? j['DidNotPlay'] as bool? ?? false,
        isMvp: j['isMvp'] as bool? ?? j['IsMvp'] as bool? ?? false,
      );
}

// ── Gol ──────────────────────────────────────────────────────────────────────

class MatchGoal {
  final String goalId;
  final String? scorerPlayerId;
  final String? scorerName;
  final String? assistPlayerId;
  final String? assistName;
  final String? time;
  final int team; // 1=A, 2=B
  final bool isOwnGoal;
  final String? scorerMatchPlayerId;
  final String? assistMatchPlayerId;

  /// Placar acumulado após este gol (calculado pelo servidor).
  final int? scoreAAfter;
  final int? scoreBAfter;

  const MatchGoal({
    required this.goalId,
    this.scorerPlayerId,
    this.scorerName,
    this.assistPlayerId,
    this.assistName,
    this.time,
    required this.team,
    required this.isOwnGoal,
    this.scorerMatchPlayerId,
    this.assistMatchPlayerId,
    this.scoreAAfter,
    this.scoreBAfter,
  });

  factory MatchGoal.fromJson(Map<String, dynamic> j) => MatchGoal(
        goalId: (j['goalId'] ?? j['GoalId'] ?? j['id'] ?? '').toString(),
        scorerPlayerId:
            (j['scorerPlayerId'] ?? j['ScorerPlayerId'])?.toString(),
        scorerName: j['scorerName'] as String? ?? j['ScorerName'] as String?,
        assistPlayerId:
            (j['assistPlayerId'] ?? j['AssistPlayerId'])?.toString(),
        assistName: j['assistName'] as String? ?? j['AssistName'] as String?,
        time: j['time'] as String? ?? j['Time'] as String?,
        team: j['team'] as int? ?? j['Team'] as int? ?? 0,
        isOwnGoal: j['isOwnGoal'] as bool? ?? j['IsOwnGoal'] as bool? ?? false,
        scorerMatchPlayerId:
            (j['scorerMatchPlayerId'] ?? j['ScorerMatchPlayerId'])?.toString(),
        assistMatchPlayerId:
            (j['assistMatchPlayerId'] ?? j['AssistMatchPlayerId'])?.toString(),
        scoreAAfter: j['scoreAAfter'] as int? ?? j['ScoreAAfter'] as int?,
        scoreBAfter: j['scoreBAfter'] as int? ?? j['ScoreBAfter'] as int?,
      );
}

// ── MVP ───────────────────────────────────────────────────────────────────────

class MvpInfo {
  final String playerId;
  final String playerName;
  const MvpInfo({required this.playerId, required this.playerName});

  factory MvpInfo.fromJson(Map<String, dynamic> j) => MvpInfo(
        playerId: (j['playerId'] ?? j['PlayerId'] ?? '').toString(),
        playerName:
            j['playerName'] as String? ?? j['PlayerName'] as String? ?? '',
      );
}

// ── Voto ──────────────────────────────────────────────────────────────────────

class VoteInfo {
  final String voterMatchPlayerId;
  final String votedMatchPlayerId;
  const VoteInfo(
      {required this.voterMatchPlayerId, required this.votedMatchPlayerId});

  factory VoteInfo.fromJson(Map<String, dynamic> j) => VoteInfo(
        voterMatchPlayerId:
            (j['voterMatchPlayerId'] ?? j['VoterMatchPlayerId'] ?? '')
                .toString(),
        votedMatchPlayerId:
            (j['votedForMatchPlayerId'] ?? j['VotedForMatchPlayerId'] ?? '')
                .toString(),
      );
}

// ── Contagem de votos ─────────────────────────────────────────────────────────

class VoteCount {
  final String matchPlayerId;
  final String playerName;
  final int count;
  const VoteCount(
      {required this.matchPlayerId,
      required this.playerName,
      required this.count});

  factory VoteCount.fromJson(Map<String, dynamic> j) => VoteCount(
        matchPlayerId:
            (j['votedForMatchPlayerId'] ?? j['VotedForMatchPlayerId'] ?? '')
                .toString(),
        playerName:
            j['votedForName'] as String? ?? j['VotedForName'] as String? ?? '',
        count: j['count'] as int? ?? j['Count'] as int? ?? 0,
      );
}

// ── Jogador para geração de times ─────────────────────────────────────────────

class TeamGenPlayer {
  final String playerId;
  final String name;
  final bool isGoalkeeper;
  final double weight;
  final double? attackRatingNorm;
  final double? defenseRatingNorm;
  final double? physicalRatingNorm;

  const TeamGenPlayer({
    required this.playerId,
    required this.name,
    required this.isGoalkeeper,
    required this.weight,
    this.attackRatingNorm,
    this.defenseRatingNorm,
    this.physicalRatingNorm,
  });

  factory TeamGenPlayer.fromJson(Map<String, dynamic> j) => TeamGenPlayer(
        playerId: (j['playerId'] ?? j['id'] ?? '').toString(),
        name: j['name'] as String? ?? j['playerName'] as String? ?? '',
        isGoalkeeper: j['isGoalkeeper'] as bool? ?? false,
        weight: (j['weight'] as num? ?? 0).toDouble(),
        attackRatingNorm: (j['attackRatingNorm'] as num?)?.toDouble(),
        defenseRatingNorm: (j['defenseRatingNorm'] as num?)?.toDouble(),
        physicalRatingNorm: (j['physicalRatingNorm'] as num?)?.toDouble(),
      );
}

// ── Explicação estruturada de uma opção ──────────────────────────────────────

class TeamGenExplanation {
  final String resumo;
  final String analiseTimeA;
  final String analiseTimeB;
  final String conclusao;

  const TeamGenExplanation({
    required this.resumo,
    required this.analiseTimeA,
    required this.analiseTimeB,
    required this.conclusao,
  });

  factory TeamGenExplanation.fromJson(Map<String, dynamic> j) =>
      TeamGenExplanation(
        resumo: j['resumo'] as String? ?? j['Resumo'] as String? ?? '',
        analiseTimeA:
            j['analiseTimeA'] as String? ?? j['AnaliseTimeA'] as String? ?? '',
        analiseTimeB:
            j['analiseTimeB'] as String? ?? j['AnaliseTimeB'] as String? ?? '',
        conclusao: j['conclusao'] as String? ?? j['Conclusao'] as String? ?? '',
      );
}

// ── Opção de time gerada ──────────────────────────────────────────────────────

class TeamGenOption {
  final List<TeamGenPlayer> teamA;
  final List<TeamGenPlayer> teamB;
  final List<TeamGenPlayer> unassigned;
  final double teamAWeight;
  final double teamBWeight;
  final double balanceDiff;
  final double? attackDiff;
  final double? defenseDiff;
  final double? physicalDiff;
  final TeamGenExplanation? explanation;

  const TeamGenOption({
    required this.teamA,
    required this.teamB,
    required this.unassigned,
    required this.teamAWeight,
    required this.teamBWeight,
    required this.balanceDiff,
    this.attackDiff,
    this.defenseDiff,
    this.physicalDiff,
    this.explanation,
  });

  factory TeamGenOption.fromJson(Map<String, dynamic> j) {
    List<TeamGenPlayer> parseList(dynamic v) => (v as List? ?? [])
        .map((e) => TeamGenPlayer.fromJson(e as Map<String, dynamic>))
        .toList();

    final rawExp = j['explanation'] ?? j['Explanation'];
    TeamGenExplanation? explanation;
    if (rawExp is Map<String, dynamic>) {
      explanation = TeamGenExplanation.fromJson(rawExp);
    }

    return TeamGenOption(
      teamA: parseList(j['teamA'] ?? j['TeamA']),
      teamB: parseList(j['teamB'] ?? j['TeamB']),
      unassigned: parseList(j['unassigned'] ?? j['Unassigned']),
      teamAWeight: (j['teamAWeight'] as num? ?? 0).toDouble(),
      teamBWeight: (j['teamBWeight'] as num? ?? 0).toDouble(),
      balanceDiff: (j['balanceDiff'] as num? ?? 0).toDouble(),
      attackDiff: (j['attackDiff'] as num?)?.toDouble(),
      defenseDiff: (j['defenseDiff'] as num?)?.toDouble(),
      physicalDiff: (j['physicalDiff'] as num?)?.toDouble(),
      explanation: explanation,
    );
  }

  TeamGenOption copyWith({
    List<TeamGenPlayer>? teamA,
    List<TeamGenPlayer>? teamB,
    List<TeamGenPlayer>? unassigned,
    double? teamAWeight,
    double? teamBWeight,
    double? balanceDiff,
  }) =>
      TeamGenOption(
        teamA: teamA ?? this.teamA,
        teamB: teamB ?? this.teamB,
        unassigned: unassigned ?? this.unassigned,
        teamAWeight: teamAWeight ?? this.teamAWeight,
        teamBWeight: teamBWeight ?? this.teamBWeight,
        balanceDiff: balanceDiff ?? this.balanceDiff,
        attackDiff: attackDiff,
        defenseDiff: defenseDiff,
        physicalDiff: physicalDiff,
        explanation: explanation,
      );
}

// ── Configurações do grupo (relevantes para partida) ──────────────────────────

class MatchGroupSettings {
  final int? minPlayers;
  final int? maxPlayers;
  final String? defaultPlaceName;
  final String? defaultKickoffTime; // formato "HH:mm:ss"

  const MatchGroupSettings({
    this.minPlayers,
    this.maxPlayers,
    this.defaultPlaceName,
    this.defaultKickoffTime,
  });

  factory MatchGroupSettings.fromJson(Map<String, dynamic> j) =>
      MatchGroupSettings(
        minPlayers: j['minPlayers'] as int? ?? j['MinPlayers'] as int?,
        maxPlayers: j['maxPlayers'] as int? ?? j['MaxPlayers'] as int?,
        defaultPlaceName: j['defaultPlaceName'] as String? ??
            j['DefaultPlaceName'] as String? ??
            j['placeName'] as String? ??
            j['PlaceName'] as String?,
        defaultKickoffTime: j['defaultKickoffTime'] as String? ??
            j['DefaultKickoffTime'] as String?,
      );
}

// ── Estado global da partida ──────────────────────────────────────────────────

class MatchState {
  const MatchState({
    this.loading = false,
    this.mutating = false,
    this.error,
    this.matchId,
    this.groupId = '',
    this.step = MatchStep.create,
    this.playedAt,
    this.placeName,
    this.canRewind = false,
    this.linkedPollId,
    this.actualStartTime,
    this.teamAColor,
    this.teamBColor,
    this.colorsLocked = false,
    this.availableColors = const [],
    this.acceptedPlayers = const [],
    this.rejectedPlayers = const [],
    this.pendingPlayers = const [],
    this.maxPlayers = 14,
    this.acceptedOverLimit = false,
    this.canAdvanceToMatchmaking = false,
    this.teamAPlayers = const [],
    this.teamBPlayers = const [],
    this.unassignedPlayers = const [],
    this.participants = const [],
    this.canStartMatch = false,
    this.teamGenOptions = const [],
    this.selectedTeamGenIdx = 0,
    this.goals = const [],
    this.teamAGoals,
    this.teamBGoals,
    this.computedMvps = const [],
    this.votes = const [],
    this.voteCounts = const [],
    this.allVoted = false,
    this.eligibleVoters = const [],
    this.canVote,
    this.hasVoted,
    this.myVotedForMatchPlayerId,
    this.groupSettings,
    // Multi-match
    this.upcomingHeaders = const [],
    this.selectedMatchIdx = 0,
  });

  final bool loading;
  final bool mutating;
  final String? error;
  final String? matchId;
  final String groupId;
  final MatchStep step;
  final DateTime? playedAt;
  final String? placeName;
  final bool canRewind;

  /// Id da votação/evento vinculado a esta partida (null = sem vínculo).
  final String? linkedPollId;

  /// Hora real (UTC) em que o admin iniciou a partida.
  final DateTime? actualStartTime;

  final TeamColorInfo? teamAColor;
  final TeamColorInfo? teamBColor;
  final bool colorsLocked;
  final List<TeamColorInfo> availableColors;

  final List<MatchPlayerInfo> acceptedPlayers;
  final List<MatchPlayerInfo> rejectedPlayers;
  final List<MatchPlayerInfo> pendingPlayers;
  final int maxPlayers;
  final bool acceptedOverLimit;

  /// Backend calculou: pode avançar para MatchMaking.
  final bool canAdvanceToMatchmaking;

  final List<MatchPlayerInfo> teamAPlayers;
  final List<MatchPlayerInfo> teamBPlayers;
  final List<MatchPlayerInfo> unassignedPlayers;
  final List<MatchPlayerInfo> participants;

  /// Backend calculou: pode iniciar a partida (ambos os times têm jogadores).
  final bool canStartMatch;

  final List<TeamGenOption> teamGenOptions;
  final int selectedTeamGenIdx;

  final List<MatchGoal> goals;
  final int? teamAGoals;
  final int? teamBGoals;

  final List<MvpInfo> computedMvps;
  final List<VoteInfo> votes;
  final List<VoteCount> voteCounts;
  final bool allVoted;
  final List<MatchPlayerInfo> eligibleVoters;

  /// Backend calculou se o usuário autenticado pode votar (null = sem jogador).
  final bool? canVote;
  final bool? hasVoted;
  final String? myVotedForMatchPlayerId;

  final MatchGroupSettings? groupSettings;

  // ── Multi-match ───────────────────────────────────────────────────────────
  /// Lista de partidas não-finalizadas (do endpoint /upcoming).
  final List<MatchHeaderDto> upcomingHeaders;
  final int selectedMatchIdx;

  // ── Derivados ─────────────────────────────────────────────────────────────

  bool get hasMatch => matchId != null && matchId!.isNotEmpty;

  /// Fallback local: usa flag do backend quando disponível.
  bool get teamsAssigned =>
      canStartMatch || (teamAPlayers.isNotEmpty && teamBPlayers.isNotEmpty);

  // Sentinel usado para distinguir "não passou" de "passou null explicitamente"
  static const Object _unset = Object();

  MatchState copyWith({
    bool? loading,
    bool? mutating,
    String? error,
    String? matchId,
    String? groupId,
    MatchStep? step,
    DateTime? playedAt,
    String? placeName,
    bool? canRewind,
    Object? linkedPollId = _unset,
    DateTime? actualStartTime,
    TeamColorInfo? teamAColor,
    TeamColorInfo? teamBColor,
    bool? colorsLocked,
    List<TeamColorInfo>? availableColors,
    List<MatchPlayerInfo>? acceptedPlayers,
    List<MatchPlayerInfo>? rejectedPlayers,
    List<MatchPlayerInfo>? pendingPlayers,
    int? maxPlayers,
    bool? acceptedOverLimit,
    bool? canAdvanceToMatchmaking,
    List<MatchPlayerInfo>? teamAPlayers,
    List<MatchPlayerInfo>? teamBPlayers,
    List<MatchPlayerInfo>? unassignedPlayers,
    List<MatchPlayerInfo>? participants,
    bool? canStartMatch,
    List<TeamGenOption>? teamGenOptions,
    int? selectedTeamGenIdx,
    List<MatchGoal>? goals,
    int? teamAGoals,
    int? teamBGoals,
    List<MvpInfo>? computedMvps,
    List<VoteInfo>? votes,
    List<VoteCount>? voteCounts,
    bool? allVoted,
    List<MatchPlayerInfo>? eligibleVoters,
    bool? canVote,
    bool? hasVoted,
    String? myVotedForMatchPlayerId,
    MatchGroupSettings? groupSettings,
    List<MatchHeaderDto>? upcomingHeaders,
    int? selectedMatchIdx,
  }) =>
      MatchState(
        loading: loading ?? this.loading,
        mutating: mutating ?? this.mutating,
        error: error ?? this.error,
        matchId: matchId ?? this.matchId,
        groupId: groupId ?? this.groupId,
        step: step ?? this.step,
        playedAt: playedAt ?? this.playedAt,
        placeName: placeName ?? this.placeName,
        canRewind: canRewind ?? this.canRewind,
        linkedPollId: identical(linkedPollId, _unset)
            ? this.linkedPollId
            : linkedPollId as String?,
        actualStartTime: actualStartTime ?? this.actualStartTime,
        teamAColor: teamAColor ?? this.teamAColor,
        teamBColor: teamBColor ?? this.teamBColor,
        colorsLocked: colorsLocked ?? this.colorsLocked,
        availableColors: availableColors ?? this.availableColors,
        acceptedPlayers: acceptedPlayers ?? this.acceptedPlayers,
        rejectedPlayers: rejectedPlayers ?? this.rejectedPlayers,
        pendingPlayers: pendingPlayers ?? this.pendingPlayers,
        maxPlayers: maxPlayers ?? this.maxPlayers,
        acceptedOverLimit: acceptedOverLimit ?? this.acceptedOverLimit,
        canAdvanceToMatchmaking:
            canAdvanceToMatchmaking ?? this.canAdvanceToMatchmaking,
        teamAPlayers: teamAPlayers ?? this.teamAPlayers,
        teamBPlayers: teamBPlayers ?? this.teamBPlayers,
        unassignedPlayers: unassignedPlayers ?? this.unassignedPlayers,
        participants: participants ?? this.participants,
        canStartMatch: canStartMatch ?? this.canStartMatch,
        teamGenOptions: teamGenOptions ?? this.teamGenOptions,
        selectedTeamGenIdx: selectedTeamGenIdx ?? this.selectedTeamGenIdx,
        goals: goals ?? this.goals,
        teamAGoals: teamAGoals ?? this.teamAGoals,
        teamBGoals: teamBGoals ?? this.teamBGoals,
        computedMvps: computedMvps ?? this.computedMvps,
        votes: votes ?? this.votes,
        voteCounts: voteCounts ?? this.voteCounts,
        allVoted: allVoted ?? this.allVoted,
        eligibleVoters: eligibleVoters ?? this.eligibleVoters,
        canVote: canVote ?? this.canVote,
        hasVoted: hasVoted ?? this.hasVoted,
        myVotedForMatchPlayerId:
            myVotedForMatchPlayerId ?? this.myVotedForMatchPlayerId,
        groupSettings: groupSettings ?? this.groupSettings,
        upcomingHeaders: upcomingHeaders ?? this.upcomingHeaders,
        selectedMatchIdx: selectedMatchIdx ?? this.selectedMatchIdx,
      );
}

// ── Detalhe enriquecido de partida upcoming (dashboard) ───────────────────────

class UpcomingMatchDetails {
  final MatchHeaderDto header;
  final List<MatchPlayerInfo> allPlayers;
  final TeamColorInfo? teamAColor;
  final TeamColorInfo? teamBColor;

  /// Título da votação/evento vinculado (null = sem vínculo ou fetch falhou).
  final String? linkedEventTitle;

  /// Emoji/ícone do evento, ex: "🌐", "⚽". Usado só quando [linkedIsEvent] = true.
  final String? linkedEventIcon;

  /// true se o linked poll for do tipo 'event' (Sim/Talvez/Não), false = enquete.
  final bool linkedIsEvent;

  /// Texto do voto do usuário, ex: "Sim", "Não". null = não votou.
  final String? myVoteText;

  const UpcomingMatchDetails({
    required this.header,
    this.allPlayers = const [],
    this.teamAColor,
    this.teamBColor,
    this.linkedEventTitle,
    this.linkedEventIcon,
    this.linkedIsEvent = false,
    this.myVoteText,
  });

  /// Aceitação ainda aberta: só nas etapas create/accept
  bool get _acceptationOpen {
    final k = header.stepKey.toLowerCase();
    return k == 'create' || k == 'accept' || k == 'acceptation';
  }

  int get acceptedCount => allPlayers
      .where((p) => p.inviteResponse == InviteResponse.accepted)
      .length;

  int get pendingCount => _acceptationOpen
      ? allPlayers
          .where((p) => p.inviteResponse == InviteResponse.pending)
          .length
      : 0;

  int get refusedCount => _acceptationOpen
      ? allPlayers
          .where((p) => p.inviteResponse == InviteResponse.declined)
          .length
      : allPlayers
          .where((p) =>
              p.inviteResponse == InviteResponse.declined ||
              p.inviteResponse == InviteResponse.pending)
          .length;

  MatchPlayerInfo? findPlayer(String playerId) {
    if (playerId.isEmpty) return null;
    try {
      return allPlayers.firstWhere((p) => p.playerId == playerId);
    } catch (_) {
      return null;
    }
  }
}

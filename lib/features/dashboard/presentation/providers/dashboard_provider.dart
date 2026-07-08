import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../calendar/data/datasources/calendar_remote_datasource.dart';
import '../../../calendar/domain/entities/calendar_event.dart';
import '../../../matches/data/datasources/match_remote_datasource.dart';
import '../../../matches/domain/entities/match_models.dart';
import '../../../polls/data/datasources/polls_remote_datasource.dart';
import '../../data/datasources/dashboard_remote_datasource.dart';
import '../../domain/entities/current_match.dart';
import '../../domain/entities/my_player.dart';
import '../../domain/entities/recent_match.dart';

// ── Helper top-level (Riverpod não permite funções dentro de lambdas de provider) ──

Future<UpcomingMatchDetails> _loadMatchDetails(MatchRemoteDataSource matchDs,
    PollsRemoteDataSource pollsDs, MatchHeaderDto header) async {
  try {
    // Busca detalhes e aceitação em paralelo (aceitação traz contagens mesmo
    // quando o /details não retorna jogadores na fase de acceptation).
    final stepKey = header.stepKey.toLowerCase();
    final bool needsAcceptation =
        stepKey == 'acceptation' || stepKey == 'accept' || stepKey == 'create';

    final detailsFuture = matchDs
        .fetchMatchDetails(header.groupId, header.matchId)
        .catchError((_) => null as Map<String, dynamic>?);

    final acceptFuture = needsAcceptation
        ? matchDs
            .fetchAcceptationSummary(header.groupId, header.matchId)
            .catchError((_) => null as Map<String, dynamic>?)
        : Future<Map<String, dynamic>?>.value(null);

    final futures = await Future.wait([detailsFuture, acceptFuture]);

    final data = futures[0];
    final acceptData = futures[1];

    // ── Parsers locais ─────────────────────────────────────────────────────

    List<MatchPlayerInfo> parsePlayers(dynamic raw, int teamNum,
        {int? forceInviteResponse}) {
      if (raw == null || raw is! List) return [];
      return raw.whereType<Map<String, dynamic>>().map((e) {
        final hasTeam = e.containsKey('team') || e.containsKey('Team');
        final hasInvite =
            e.containsKey('inviteResponse') || e.containsKey('InviteResponse');
        final patched = {
          ...e,
          if (!hasTeam) 'team': teamNum,
          if (!hasInvite && forceInviteResponse != null)
            'inviteResponse': forceInviteResponse,
        };
        return MatchPlayerInfo.fromJson(patched);
      }).toList();
    }

    TeamColorInfo? parseColor(dynamic c) =>
        c is Map<String, dynamic> ? TeamColorInfo.fromJson(c) : null;

    // ── Montar lista de jogadores ──────────────────────────────────────────
    // Prioridade: /details → /acceptation como fallback.

    List<MatchPlayerInfo> allPlayers = [];

    if (data != null) {
      final aPlayers =
          parsePlayers(data['teamAPlayers'] ?? data['TeamAPlayers'], 1);
      final bPlayers =
          parsePlayers(data['teamBPlayers'] ?? data['TeamBPlayers'], 2);
      final unassigned = parsePlayers(
        data['unassignedPlayers'] ??
            data['UnassignedPlayers'] ??
            data['pendingPlayers'] ??
            data['PendingPlayers'] ??
            data['players'] ??
            data['Players'] ??
            data['matchPlayers'] ??
            data['MatchPlayers'],
        0,
      );
      allPlayers = [...aPlayers, ...bPlayers, ...unassigned];
    }

    // Para a etapa de aceitação, /acceptation é fonte primária dos inviteResponse
    // (o /details pode retornar os jogadores sem o campo inviteResponse, fazendo
    // todos ficarem como "pending"). Se /acceptation retornou dados, usa eles.
    if (needsAcceptation && acceptData != null) {
      final fromAccept = [
        ...parsePlayers(
            acceptData['acceptedPlayers'] ?? acceptData['AcceptedPlayers'], 0,
            forceInviteResponse: 3),
        ...parsePlayers(
            acceptData['rejectedPlayers'] ?? acceptData['RejectedPlayers'], 0,
            forceInviteResponse: 2),
        ...parsePlayers(
          acceptData['pendingPlayers'] ??
              acceptData['PendingPlayers'] ??
              acceptData['unrespondedPlayers'] ??
              acceptData['players'] ??
              acceptData['Players'],
          0,
          forceInviteResponse: 1,
        ),
      ];
      if (fromAccept.isNotEmpty) allPlayers = fromAccept;
    }

    // Fallback final: /details também não retornou jogadores nem /acceptation.
    if (allPlayers.isEmpty && acceptData != null && !needsAcceptation) {
      allPlayers = [
        ...parsePlayers(
            acceptData['acceptedPlayers'] ?? acceptData['AcceptedPlayers'], 0,
            forceInviteResponse: 3),
        ...parsePlayers(
            acceptData['rejectedPlayers'] ?? acceptData['RejectedPlayers'], 0,
            forceInviteResponse: 2),
        ...parsePlayers(
          acceptData['pendingPlayers'] ??
              acceptData['PendingPlayers'] ??
              acceptData['unrespondedPlayers'] ??
              acceptData['players'] ??
              acceptData['Players'],
          0,
          forceInviteResponse: 1,
        ),
      ];
    }

    TeamColorInfo? teamAColor;
    TeamColorInfo? teamBColor;
    if (data != null) {
      teamAColor = parseColor(data['teamAColor'] ?? data['ColorTeamA']);
      teamBColor = parseColor(data['teamBColor'] ?? data['ColorTeamB']);
    }

    // ── Poll / evento vinculado ────────────────────────────────────────────

    String? linkedEventTitle;
    String? linkedEventIcon;
    bool linkedIsEvent = false;
    String? myVoteText;

    final pollId = header.linkedPollId;
    if (pollId != null && pollId.isNotEmpty) {
      try {
        final poll = await pollsDs.getPoll(header.groupId, pollId);
        linkedEventTitle = poll.title;
        linkedEventIcon = poll.eventIcon;
        linkedIsEvent = poll.isEvent;

        if (poll.myVotedOptionIds.isNotEmpty) {
          try {
            final opt = poll.options
                .firstWhere((o) => poll.myVotedOptionIds.contains(o.id));
            myVoteText = opt.text;
          } catch (_) {
            myVoteText = linkedIsEvent ? 'Sim' : 'Votou';
          }
        }
      } catch (_) {}
    }

    return UpcomingMatchDetails(
      header: header,
      allPlayers: allPlayers,
      teamAColor: teamAColor,
      teamBColor: teamBColor,
      linkedEventTitle: linkedEventTitle,
      linkedEventIcon: linkedEventIcon,
      linkedIsEvent: linkedIsEvent,
      myVoteText: myVoteText,
    );
  } catch (_) {
    return UpcomingMatchDetails(header: header);
  }
}

// ── DataSources ───────────────────────────────────────────────────────────────

final _dashboardDsProvider = Provider<DashboardRemoteDataSource>(
  (ref) => DashboardRemoteDataSource(ref.watch(dioProvider)),
);

final _matchDsProvider = Provider<MatchRemoteDataSource>(
  (ref) => MatchRemoteDataSource(ref.watch(dioProvider)),
);

final _calendarDsProvider = Provider<CalendarRemoteDataSource>(
  (ref) => CalendarRemoteDataSource(ref.watch(dioProvider)),
);

final _pollsDsProvider = Provider<PollsRemoteDataSource>(
  (ref) => PollsRemoteDataSource(ref.watch(dioProvider)),
);

// ── Jogadores do usuário ──────────────────────────────────────────────────────

/// Não usa autoDispose — precisa sobreviver à navegação entre abas para que
/// Histórico, Replays e outras telas encontrem o grupo do jogador sem refetch.
final myPlayersProvider = FutureProvider<List<MyPlayer>>((ref) {
  // Re-fetch sempre que a conta ativa mudar.
  ref.watch(accountStoreProvider.select((s) => s.activeAccountId));
  final ds = ref.watch(_dashboardDsProvider);
  return ds.fetchMyPlayers();
});

// ── Partida atual ─────────────────────────────────────────────────────────────

final currentMatchProvider =
    FutureProvider.autoDispose.family<CurrentMatch?, String>((ref, groupId) {
  final ds = ref.watch(_dashboardDsProvider);
  return ds.fetchCurrentMatch(groupId);
});

// ── Últimas partidas do jogador ───────────────────────────────────────────────

final recentMatchesProvider = FutureProvider.autoDispose
    .family<List<RecentMatch>, ({String groupId, String playerId})>(
  (ref, args) {
    final ds = ref.watch(_dashboardDsProvider);
    return ds.fetchRecentMatches(args.groupId, args.playerId);
  },
);

// ── Jogador ativo ─────────────────────────────────────────────────────────────

/// ID do jogador selecionado manualmente pelo usuário no Dashboard.
/// Não usa autoDispose — a seleção precisa persistir ao navegar entre abas.
final activePlayerIdProvider = StateProvider<String?>((ref) => null);

/// Jogador ativo resolvido (usa o activePlayerId do account store ou
/// o primeiro da lista). Não autoDispose pelo mesmo motivo acima.
final activePlayerProvider = Provider<MyPlayer?>((ref) {
  final playersAsync = ref.watch(myPlayersProvider);
  final accountActive = ref.watch(accountStoreProvider).activeAccount;
  final manualId = ref.watch(activePlayerIdProvider);

  // Enquanto re-fetch está em andamento (troca de conta), valueOrNull ainda
  // contém os jogadores da conta anterior. Retorna null para não exibir dados
  // do grupo errado no topo e no dashboard durante a transição.
  if (playersAsync.isLoading) return null;

  final players = playersAsync.valueOrNull ?? [];
  if (players.isEmpty) return null;

  final explicitId = manualId ?? accountActive?.activePlayerId;
  if (explicitId != null) {
    final matches = players.where((p) => p.playerId == explicitId);
    return matches.isEmpty ? null : matches.first;
  }

  // Sem ID explícito salvo: usa o primeiro jogador disponível.
  return players.first;
});

// ── Próximas partidas: headers simples ────────────────────────────────────────

final upcomingMatchesProvider = FutureProvider.autoDispose
    .family<List<MatchHeaderDto>, String>((ref, groupId) {
  return ref.watch(_matchDsProvider).fetchUpcomingMatches(groupId);
});

// ── Próximas partidas: headers + detalhes completos (dashboard rich cards) ────

final upcomingMatchesFullProvider = FutureProvider.autoDispose
    .family<List<UpcomingMatchDetails>, String>((ref, groupId) async {
  final matchDs = ref.read(_matchDsProvider);
  final pollsDs = ref.read(_pollsDsProvider);
  final headers = await matchDs.fetchUpcomingMatches(groupId);
  if (headers.isEmpty) return [];
  return Future.wait(
      headers.map((h) => _loadMatchDetails(matchDs, pollsDs, h)));
});

// ── Próximos eventos (dashboard carrossel) ────────────────────────────────────

final upcomingEventsProvider = FutureProvider.autoDispose
    .family<List<CalendarEvent>, String>((ref, groupId) async {
  final ds = ref.read(_calendarDsProvider);
  final now = DateTime.now();
  final end = DateTime(now.year, now.month + 4, now.day);
  final start =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final endS =
      '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
  final all = await ds.fetchEvents(groupId, start, endS);
  final events = all.where((e) => e.type != 'match').toList()
    ..sort((a, b) {
      final aTime = a.time ?? '00:00';
      final bTime = b.time ?? '00:00';
      return '${a.date}T$aTime'.compareTo('${b.date}T$bTime');
    });
  return events.take(5).toList();
});

class ApiConstants {
  ApiConstants._();

  // Auth
  static const String login = '/api/Authentication/login';
  static const String refreshToken = '/api/Authentication/refresh-token';

  // Users
  static const String users = '/api/Users';
  static String userById(String id) => '/api/Users/$id';

  // Groups
  static const String groups = '/api/Groups';
  static String groupById(String id) => '/api/Groups/$id';
  static String groupsByAdmin(String adminId) => '/api/Groups/admin/$adminId';
  static String groupsByFinanceiro(String finId) =>
      '/api/Groups/financeiro/$finId';
  static String myGroupRoles(String groupId) => '/api/Groups/$groupId/my-roles';

  // Players
  static const String playersMe = '/api/Players/mine';
  static String playerById(String id) => '/api/Players/$id';
  static String birthdayStatus(String groupId) =>
      '/api/Players/group/$groupId/birthday-status';
  static String visualStats(String groupId) =>
      '/api/TeamGeneration/visual-stats/$groupId';

  // Players (group admin)
  static const String playersCreate = '/api/Players';
  static String groupPlayers(String groupId) => '/api/Players/group/$groupId';
  static String playerOps(String id) => '/api/Players/$id';
  static String playerLeaveGroup(String id) => '/api/players/$id/leave';
  static String playerRemoveFromGroup(String id) =>
      '/api/Players/$id/remove-from-group';
  static String playerToggleGoalkeeper(String id) =>
      '/api/Players/$id/toggle-goalkeeper';

  // Group invites
  static String groupInvites(String groupId) => '/api/Groups/$groupId/invites';
  static String groupPendingInvites(String groupId) =>
      '/api/Groups/$groupId/invites/pending';
  static String groupCancelInvite(String groupId, String inviteId) =>
      '/api/Groups/$groupId/invites/$inviteId';
  static const String myGroupInvites = '/api/Groups/invites/mine';
  static const String myGroupInvitesCount = '/api/Groups/invites/mine/count';
  static String groupInviteAccept(String inviteId) =>
      '/api/Groups/invites/$inviteId/accept';
  static String groupInviteReject(String inviteId) =>
      '/api/Groups/invites/$inviteId/reject';

  // Users – search (paginated)
  static String usersListSearch(String q, int pageSize) =>
      '/api/Users?search=${Uri.encodeComponent(q)}&pageSize=$pageSize';

  // Matches
  static String currentMatch(String groupId) =>
      '/api/matches/group/$groupId/current';

  /// Lista de partidas não-finalizadas do grupo (máx. 5 simultâneas).
  static String upcomingMatches(String groupId) =>
      '/api/matches/group/$groupId/upcoming';
  static String matchDetails(String groupId, String matchId) =>
      '/api/Matches/group/$groupId/$matchId/details';
  static String playerRecentMatches(String groupId) =>
      '/api/Matches/group/$groupId/player-recent';
  static String matchHistory(String groupId) =>
      '/api/Matches/group/$groupId/history';

  // Payments – mensalidades
  static String monthlyGrid(String groupId, int year) =>
      '/api/groups/$groupId/payments/monthly/$year';
  static String upsertMonthly(String groupId) =>
      '/api/groups/$groupId/payments/monthly';
  static String monthlyProof(
          String groupId, String playerId, int year, int month) =>
      '/api/groups/$groupId/payments/monthly/$year/$month/$playerId/proof';
  static String myMonthlyRow(String groupId, int year) =>
      '/api/groups/$groupId/payments/monthly/$year/me';

  // Payments – cobranças extras
  static String extraCharges(String groupId) =>
      '/api/groups/$groupId/payments/extra-charges';
  static String extraChargeById(String groupId, String chargeId) =>
      '/api/groups/$groupId/payments/extra-charges/$chargeId';
  static String extraChargeBulkDiscount(String groupId, String chargeId) =>
      '/api/groups/$groupId/payments/extra-charges/$chargeId/bulk-discount';
  static String extraChargePayment(
          String groupId, String chargeId, String playerId) =>
      '/api/groups/$groupId/payments/extra-charges/$chargeId/players/$playerId';
  static String extraChargeProof(
          String groupId, String chargeId, String playerId) =>
      '/api/groups/$groupId/payments/extra-charges/$chargeId/$playerId/proof';
  static String myExtraCharges(String groupId) =>
      '/api/groups/$groupId/payments/extra-charges/me';

  // Payments – resumo
  static String myPaymentSummary(String groupId) =>
      '/api/groups/$groupId/payments/my';
  static String myPendingItems(String groupId) =>
      '/api/groups/$groupId/payments/my-pending-items';
  static String paySelected(String groupId) =>
      '/api/groups/$groupId/payments/pay-selected';

  /// Totais de pendências por jogador (admin).
  static String paymentPendingTotals(String groupId) =>
      '/api/groups/$groupId/payments/pending-totals';
  static String initiateMonth(String groupId, int year, int month) =>
      '/api/groups/$groupId/payments/monthly/$year/$month/initiate';
  static String isMonthInitiated(String groupId, int year, int month) =>
      '/api/groups/$groupId/payments/monthly/$year/$month/is-initiated';
  static String paymentSummaryByPlayer(String groupId, String playerId) =>
      '/api/groups/$groupId/payments/summary/$playerId';

  // Calendar
  static String calendarEvents(String groupId, String start, String end) =>
      '/api/Calendar/group/$groupId?start=$start&end=$end';
  static String calendarEventById(String groupId, String id) =>
      '/api/Calendar/group/$groupId/events/$id';
  static String calendarEvents2(String groupId) =>
      '/api/Calendar/group/$groupId/events';
  static String calendarCategories(String groupId) =>
      '/api/Calendar/group/$groupId/categories';
  static String calendarCategoryById(String groupId, String id) =>
      '/api/Calendar/group/$groupId/categories/$id';

  // Users – mutations
  static String changePassword(String id) => '/api/users/$id/password';
  static String deactivateUser(String id) => '/api/users/$id/inactivate';
  static String activateUser(String id) => '/api/users/$id/reactivate';

  // Group settings (separate resource from group detail)
  static String groupSettings(String groupId) =>
      '/api/GroupSettings/group/$groupId';

  // Group members management
  static String groupAdmins(String id) => '/api/Groups/$id/admins';
  static String groupAdminById(String id, String uid) =>
      '/api/Groups/$id/admins/$uid';
  static String groupFinanceiros(String id) => '/api/Groups/$id/financeiros';
  static String groupFinanceiroById(String id, String uid) =>
      '/api/Groups/$id/financeiros/$uid';
  static String usersSearch(String q) =>
      '/api/Users?search=${Uri.encodeComponent(q)}';

  // Polls
  static String polls(String groupId) => '/api/Polls/group/$groupId';
  static String pollById(String groupId, String pollId) =>
      '/api/Polls/group/$groupId/$pollId';
  static String createEventPoll(String groupId) =>
      '/api/Polls/group/$groupId/event';
  static String closePoll(String groupId, String pollId) =>
      '/api/Polls/group/$groupId/$pollId/close';
  static String reopenPoll(String groupId, String pollId) =>
      '/api/Polls/group/$groupId/$pollId/reopen';
  static String deletePoll(String groupId, String pollId) =>
      '/api/Polls/group/$groupId/$pollId';
  static String pollOptions(String groupId, String pollId) =>
      '/api/Polls/group/$groupId/$pollId/options';
  static String pollOptionById(String groupId, String pollId, String optId) =>
      '/api/Polls/group/$groupId/$pollId/options/$optId';
  static String castVote(String groupId, String pollId) =>
      '/api/Polls/group/$groupId/$pollId/vote';
  static String adminVote(String groupId, String pollId) =>
      '/api/Polls/group/$groupId/$pollId/admin-vote';

  // Team Colors
  static String teamColors(String groupId) => '/api/TeamColor/group/$groupId';
  static String teamColorById(String groupId, String id) =>
      '/api/TeamColor/group/$groupId/$id';
  static String teamColorActivate(String groupId, String id) =>
      '/api/TeamColor/group/$groupId/$id/activate';
  static String teamColorDeactivate(String groupId, String id) =>
      '/api/TeamColor/group/$groupId/$id/deactivate';

  // Matches – workflow completo
  static String matchCreate(String groupId) => '/api/Matches/group/$groupId';
  static String matchById(String groupId, String id) =>
      '/api/Matches/group/$groupId/$id';
  static String matchDelete(String groupId, String id) =>
      '/api/Matches/group/$groupId/$id';
  static String matchHeader(String groupId, String id) =>
      '/api/Matches/group/$groupId/$id/header';
  static String matchAcceptation(String groupId, String id) =>
      '/api/Matches/group/$groupId/$id/acceptation';
  static String matchAcceptationSummary(String groupId, String id) =>
      '/api/Matches/group/$groupId/$id/acceptation/summary';
  static String matchMatchmaking(String groupId, String id) =>
      '/api/Matches/group/$groupId/$id/matchmaking';
  static String matchPostgame(String groupId, String id) =>
      '/api/Matches/group/$groupId/$id/postgame';
  static String matchAccept(String groupId, String id) =>
      '/api/matches/group/$groupId/$id/my-invite/accept';
  static String matchReject(String groupId, String id) =>
      '/api/matches/group/$groupId/$id/my-invite/reject';
  static String matchColors(String groupId, String id) =>
      '/api/Matches/group/$groupId/$id/colors';
  static String matchStart(String groupId, String id) =>
      '/api/Matches/group/$groupId/$id/start';
  static String matchEnd(String groupId, String id) =>
      '/api/Matches/group/$groupId/$id/end';
  static String matchVote(String groupId, String id) =>
      '/api/Matches/group/$groupId/$id/vote';
  static String matchScore(String groupId, String id) =>
      '/api/Matches/group/$groupId/$id/score';
  static String matchGoals(String groupId, String id) =>
      '/api/Matches/group/$groupId/$id/goals';
  static String matchGoalById(String groupId, String id, String goalId) =>
      '/api/Matches/group/$groupId/$id/goals/$goalId';
  static String matchTeams(String groupId, String id) =>
      '/api/Matches/group/$groupId/$id/teams';
  static String matchSwap(String groupId, String id) =>
      '/api/Matches/group/$groupId/$id/swap';
  static String matchFinalize(String groupId, String id) =>
      '/api/Matches/group/$groupId/$id/finalize';
  static String matchRewind(String groupId, String id) =>
      '/api/Matches/group/$groupId/$id/rewind';
  static String matchGoToMatchmaking(String groupId, String id) =>
      '/api/matches/group/$groupId/$id/matchmaking';
  static String matchGoToPostGame(String groupId, String id) =>
      '/api/matches/group/$groupId/$id/postgame';
  static String matchGuest(String groupId, String id) =>
      '/api/matches/group/$groupId/$id/guests';
  static String matchPlayerRole(String groupId, String id, String mpId) =>
      '/api/Matches/group/$groupId/$id/players/$mpId/role';

  /// Marca/desmarca um jogador como "não foi jogar" (DidNotPlay).
  static String matchPlayerNoShow(String groupId, String id, String mpId) =>
      '/api/Matches/group/$groupId/$id/players/$mpId/no-show';

  /// Vincula ou desvincula uma votação/evento a esta partida.
  static String matchLinkedPoll(String groupId, String id) =>
      '/api/Matches/group/$groupId/$id/linked-poll';

  // Match invite — aceitar/rejeitar pelo token JWT (sem playerId)
  static String matchMyInviteAccept(String groupId, String matchId) =>
      '/api/matches/group/$groupId/$matchId/my-invite/accept';
  static String matchMyInviteReject(String groupId, String matchId) =>
      '/api/matches/group/$groupId/$matchId/my-invite/reject';

  // Match invite — aceitar/rejeitar com playerId explícito (admin agindo por outro jogador)
  static String matchInviteAccept(String groupId, String matchId) =>
      '/api/Matches/group/$groupId/$matchId/invite/accept';
  static String matchInviteReject(String groupId, String matchId) =>
      '/api/Matches/group/$groupId/$matchId/invite/reject';

  // TeamGeneration
  static const String teamGenGenerate = '/api/TeamGeneration/generate';
  static String teamGenSpotlight(String groupId) =>
      '/api/TeamGeneration/spotlight/$groupId';
  static String playerHistory(String groupId) =>
      '/api/Matches/group/$groupId/player-history';

  // Match card (share image)
  static String matchCard(String groupId) =>
      '/api/MatchCard/group/$groupId/generate';

  // Match extras
  static String matchBulkGoals(String groupId, String id) =>
      '/api/Matches/group/$groupId/$id/goals/bulk';
  static String matchReapplyMvp(String groupId, String id) =>
      '/api/Matches/group/$groupId/$id/reapply-mvp';
  static String matchPublishEvent(String groupId, String id) =>
      '/api/Matches/group/$groupId/$id/events';
  static String matchReplays(String groupId, String id) =>
      '/api/Matches/group/$groupId/$id/replays';
  static String allGroupReplays(String groupId) =>
      '/api/Matches/group/$groupId/replays/all';
  static String myLikedReplays(String groupId) =>
      '/api/Matches/group/$groupId/replays/my-likes';
  static String myFavoriteReplays(String groupId) =>
      '/api/Matches/group/$groupId/replays/my-favorites';
  static String replayLike(String groupId, String clipId) =>
      '/api/Matches/group/$groupId/replays/$clipId/like';
  static String replayFavorite(String groupId, String clipId) =>
      '/api/Matches/group/$groupId/replays/$clipId/favorite';
  static String replayStream(String groupId, String clipId) =>
      '/api/Matches/group/$groupId/replays/$clipId/stream';
  static String replayDelete(String groupId, String clipId) =>
      '/api/Matches/group/$groupId/replays/$clipId';

  // Polls – show votes toggle
  static String pollShowVotes(String groupId, String pollId) =>
      '/api/Polls/group/$groupId/$pollId/show-votes';
  static String pollDeadline(String groupId, String pollId) =>
      '/api/Polls/group/$groupId/$pollId/deadline';
  static String pollGuests(String groupId, String pollId) =>
      '/api/Polls/group/$groupId/$pollId/guests';
  static String pollGuestById(String groupId, String pollId, String guestId) =>
      '/api/Polls/group/$groupId/$pollId/guests/$guestId';

  // Absences
  static const String absences = '/api/absences';
  static const String absencesMine = '/api/absences/mine';
  static String absenceById(String id) => '/api/absences/$id';
  static String absencesByGroup(String groupId) =>
      '/api/absences/group/$groupId';

  // Push Notifications
  static const String pushRegisterToken = '/api/push/register-token';

  // Notifications inbox
  static const String myNotifications = '/api/Notifications/mine';
  static const String myNotificationsUnreadCount =
      '/api/Notifications/mine/unread-count';
  static String notificationMarkRead(String id) =>
      '/api/Notifications/$id/read';
  static const String notificationsMarkAllRead =
      '/api/Notifications/mine/read-all';
}

/// Computa a rota interna do app para um determinado tipo de notificação.
///
/// [type]  campo `type` do payload FCM ou da entidade UserNotification.
/// [data]  mapa flat com IDs associados (matchId, groupId, pollId, etc.).
///         No FCM, vem diretamente de `message.data`.
///         No inbox, vem de `AppNotification.dataJson`.
///
/// Retorna uma string de rota GoRouter (ex: '/app/matches?matchId=xxx'),
/// ou '/app' como fallback genérico.
String notificationRoute(String type, Map<String, dynamic> data) {
  final matchId = data['matchId'] as String?;
  final groupId = data['groupId'] as String?;

  switch (type) {
    // ── Partidas ──────────────────────────────────────────────────────────

    case 'match_invite':
    case 'match_invite_reminder':
    case 'match_started':
    case 'teams_assigned':
    case 'match_ended':
    case 'match_no_quorum':
    case 'mvp_voting_reminder':
    case 'attendance_accepted':
    case 'attendance_rejected':
      if (_ok(matchId)) return '/app/matches?matchId=$matchId';
      return '/app/matches';

    case 'match_finalized':
    case 'match_mvp':
      if (_ok(groupId) && _ok(matchId)) {
        return '/app/history/$groupId/$matchId';
      }
      return '/app/history';

    // ── Votações ──────────────────────────────────────────────────────────

    case 'poll_created':
    case 'poll_closed':
    case 'poll_reminder':
    case 'poll_deadline_changed':
      return '/app/polls';

    // ── Calendário ────────────────────────────────────────────────────────

    case 'event_created':
    case 'event_deleted':
    case 'event_reminder':
      return '/app/calendar';

    // ── Financeiro ────────────────────────────────────────────────────────

    case 'payment_pending':
    case 'payment_confirmed':
    case 'monthly_payment_reminder':
    case 'extra_charge_discount':
      return '/app/payments';

    // ── Grupo / membros ───────────────────────────────────────────────────

    case 'group_invite':
      return '/app/invites';

    case 'player_left':
    case 'player_removed':
    case 'player_removed_self':
    case 'promoted_admin':
    case 'promoted_financeiro':
      return '/app/groups';

    // ── Apostas ───────────────────────────────────────────────────────────

    case 'bet_resolved':
    case 'bet_created':
      return '/app/bet';

    // ── Outros ────────────────────────────────────────────────────────────

    case 'birthday':
      return '/app/birthdays';

    default:
      return '/app';
  }
}

bool _ok(String? s) => s != null && s.isNotEmpty;

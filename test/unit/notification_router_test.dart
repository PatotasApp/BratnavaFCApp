import 'package:patotas_app/core/push/notification_router.dart';
import 'package:patotas_app/features/notifications/domain/entities/app_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('notificationRoute', () {
    test('abre a partida relacionada', () {
      expect(
        notificationRoute('attendance_confirmed', {'matchId': 'match-1'}),
        '/app/matches?matchId=match-1',
      );
    });

    test('separa eventos de votações comuns', () {
      expect(
        notificationRoute('poll_created', {'pollType': 'event'}),
        '/app/polls/events',
      );
      expect(
        notificationRoute('poll_created', {'pollType': 'vote'}),
        '/app/polls/votes',
      );
    });

    test('abre pagamentos para cobrança quitada', () {
      expect(
        notificationRoute('charge_fully_paid', const {}),
        '/app/payments',
      );
    });

    test('abre a conta para alteração de senha', () {
      expect(
        notificationRoute('password_changed', const {}),
        '/app/account',
      );
    });

    test('não abre mais a funcionalidade removida de apostas', () {
      expect(notificationRoute('bet_created', const {}), '/app');
      expect(notificationRoute('bet_resolved', const {}), '/app');
    });

    test('abre a partida para notificações da lista de espera', () {
      expect(
        notificationRoute('match_waiting_list', {'matchId': 'match-waiting'}),
        '/app/matches?matchId=match-waiting',
      );
      expect(
        notificationRoute(
            'match_waiting_promoted', {'matchId': 'match-promoted'}),
        '/app/matches?matchId=match-promoted',
      );
    });

    test('abre a partida do convidado externo', () {
      expect(
        notificationRoute(
            'match_application_invite', {'matchId': 'guest-match'}),
        '/app/guest-match/guest-match',
      );
      expect(
        notificationRoute('match_application_rejected', const {}),
        '/app/match-invitations',
      );
    });

    test('abre o plano da patota no lembrete de assinatura', () {
      expect(
        notificationRoute('billing_reminder', {'groupId': 'group-1'}),
        '/app/plano?groupId=group-1',
      );
    });
  });

  group('AppNotification', () {
    test('incorpora o groupId top-level ao payload usado pelo sino', () {
      final notification = AppNotification.fromJson({
        'id': 'notification-1',
        'type': 'payment_pending',
        'title': 'Pagamento',
        'body': 'Há um pagamento pendente',
        'isRead': false,
        'createdAt': '2026-11-26T12:00:00Z',
        'groupId': 'group-from-column',
        'dataJson': '{"type":"payment_pending"}',
      });

      expect(notification.dataJson?['groupId'], 'group-from-column');
    });
  });
}

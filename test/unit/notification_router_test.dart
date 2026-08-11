import 'package:bratnava_fc_app/core/push/notification_router.dart';
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
  });
}

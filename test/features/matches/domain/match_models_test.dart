import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/matches/domain/entities/match_models.dart';
import 'package:patotas_app/shared/domain/participation_history_item.dart';

void main() {
  group('matchStepLabel', () {
    test('traduz status técnicos da API', () {
      expect(matchStepLabel('Finalized'), 'Finalizada');
      expect(matchStepLabel('MatchMaking'), 'Montagem dos times');
    });

    test('preserva um rótulo desconhecido', () {
      expect(matchStepLabel('NovaEtapa'), 'NovaEtapa');
    });
  });

  test('interpreta resposta 4 como lista de espera', () {
    final player = MatchPlayerInfo.fromJson({
      'matchPlayerId': 'match-player',
      'playerId': 'player',
      'playerName': 'Jogador',
      'inviteResponse': 4,
    });

    expect(player.inviteResponse, InviteResponse.waiting);
  });

  test('header preserva a localização estruturada da partida', () {
    final header = MatchHeaderDto.fromJson({
      'matchId': 'match-1',
      'groupId': 'group-1',
      'playedAt': '2026-11-24T22:00:00Z',
      'placeName': 'Arena Central',
      'placeAddress': 'Rua das Flores, 10',
      'placeLatitude': -23.55052,
      'placeLongitude': -46.633308,
      'status': 1,
      'statusName': 'Scheduled',
      'stepKey': 'accept',
      'canRewind': false,
    });

    expect(header.placeAddress, 'Rua das Flores, 10');
    expect(header.placeLatitude, -23.55052);
    expect(header.placeLongitude, -46.633308);
  });

  test('histórico converte horário para o fuso local e traduz a ação', () {
    final item = ParticipationHistoryItem.fromJson({
      'action': 'promoted',
      'occurredAt': '2026-11-24T02:30:00Z',
      'performedByAdmin': false,
    });

    expect(item.label, 'Foi promovido para a partida');
    expect(item.occurredAt.isUtc, isFalse);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/matches/domain/entities/match_models.dart';
import 'package:patotas_app/features/matches/domain/entities/mvp_leaders.dart';

void main() {
  test('retorna todos os líderes quando a votação está empatada', () {
    const counts = [
      VoteCount(matchPlayerId: '1', playerName: 'Artur', count: 1),
      VoteCount(matchPlayerId: '2', playerName: 'Bruno', count: 1),
    ];

    expect(leadingMvpVoteCounts(counts).map((vote) => vote.playerName), [
      'Artur',
      'Bruno',
    ]);
  });

  test('retorna somente quem possui a maior contagem', () {
    const counts = [
      VoteCount(matchPlayerId: '1', playerName: 'Artur', count: 2),
      VoteCount(matchPlayerId: '2', playerName: 'Bruno', count: 1),
    ];

    expect(leadingMvpVoteCounts(counts).map((vote) => vote.playerName), [
      'Artur',
    ]);
  });

  test('retorna lista vazia quando ainda não há votos', () {
    expect(leadingMvpVoteCounts(const []), isEmpty);
  });
}

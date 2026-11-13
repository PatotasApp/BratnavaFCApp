import 'match_models.dart';

/// Retorna todos os jogadores empatados na maior contagem de votos.
///
/// A ordem recebida da API é preservada para que a prévia não mude de posição
/// entre atualizações com a mesma pontuação.
List<VoteCount> leadingMvpVoteCounts(Iterable<VoteCount> voteCounts) {
  final counts = voteCounts.toList(growable: false);
  if (counts.isEmpty) return const [];

  final maxVotes = counts
      .map((vote) => vote.count)
      .reduce((currentMax, count) => count > currentMax ? count : currentMax);

  return counts.where((vote) => vote.count == maxVotes).toList(growable: false);
}

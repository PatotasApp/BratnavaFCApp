class ParticipationHistoryItem {
  final String action;
  final String? details;
  final DateTime occurredAt;
  final bool performedByAdmin;

  const ParticipationHistoryItem({
    required this.action,
    this.details,
    required this.occurredAt,
    required this.performedByAdmin,
  });

  factory ParticipationHistoryItem.fromJson(Map<String, dynamic> json) =>
      ParticipationHistoryItem(
        action: (json['action'] ?? json['Action'] ?? '').toString(),
        details: (json['details'] ?? json['Details'])?.toString(),
        occurredAt: DateTime.parse(
          (json['occurredAt'] ?? json['OccurredAt']).toString(),
        ).toLocal(),
        performedByAdmin: json['performedByAdmin'] as bool? ??
            json['PerformedByAdmin'] as bool? ??
            false,
      );

  String get label => switch (action) {
        'accepted' => 'Confirmou presença',
        'rejected' => 'Recusou presença',
        'waiting' => 'Entrou na lista de espera',
        'promoted' => 'Foi promovido para a partida',
        'tentative' => 'Respondeu talvez',
        'voted' => 'Registrou um voto',
        'removed_vote' => 'Removeu o voto',
        _ => action,
      };
}

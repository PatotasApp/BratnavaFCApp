import 'package:equatable/equatable.dart';

class PollSummary extends Equatable {
  final String id;
  final String title;
  final String? description;
  final bool allowMultipleVotes;
  final bool showVotes;
  final String status; // 'open' | 'closed'
  final String? deadlineDate;
  final String? deadlineTime;
  final int optionCount;
  final int totalVoters;
  final bool hasVoted;
  final String createDate;
  final String type; // 'poll' | 'event'
  final String? eventDate;
  final String? eventTime;
  final String? eventLocation;
  final String? eventIcon;
  final String? costType;
  final double? costAmount;

  /// Calculado pelo servidor: poll aberta E prazo não vencido.
  /// Usar este campo em vez do getter [deadlinePassed] local.
  final bool isAcceptingVotes;

  /// Id da partida vinculada a esta votação/evento (null = sem vínculo).
  final String? linkedMatchId;

  final bool allowGuests;
  const PollSummary({
    required this.id,
    required this.title,
    this.description,
    required this.allowMultipleVotes,
    required this.showVotes,
    required this.status,
    this.deadlineDate,
    this.deadlineTime,
    required this.optionCount,
    required this.totalVoters,
    required this.hasVoted,
    required this.createDate,
    required this.type,
    this.eventDate,
    this.eventTime,
    this.eventLocation,
    this.eventIcon,
    this.costType,
    this.costAmount,
    this.isAcceptingVotes = true,
    this.linkedMatchId,
    this.allowGuests = false,
  });

  bool get isOpen => status == 'open';
  bool get isEvent => type == 'event';

  /// @deprecated Prefira [isAcceptingVotes] (calculado pelo servidor).
  bool get deadlinePassed {
    if (deadlineDate == null) return false;
    final time = deadlineTime ?? '23:59';
    final deadline = DateTime.tryParse('${deadlineDate}T$time:00');
    if (deadline == null) return false;
    return DateTime.now().isAfter(deadline);
  }

  factory PollSummary.fromJson(Map<String, dynamic> j) => PollSummary(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        description: j['description'] as String?,
        allowMultipleVotes: j['allowMultipleVotes'] as bool? ?? false,
        showVotes: j['showVotes'] as bool? ?? false,
        status: j['status'] as String? ?? 'open',
        deadlineDate: j['deadlineDate'] as String?,
        deadlineTime: j['deadlineTime'] as String?,
        optionCount: j['optionCount'] as int? ?? 0,
        totalVoters: j['totalVoters'] as int? ?? 0,
        hasVoted: j['hasVoted'] as bool? ?? false,
        createDate: j['createDate'] as String? ?? '',
        type: j['type'] as String? ?? 'poll',
        eventDate: j['eventDate'] as String?,
        eventTime: j['eventTime'] as String?,
        eventLocation: j['eventLocation'] as String?,
        eventIcon: j['eventIcon'] as String?,
        costType: j['costType'] as String?,
        costAmount: (j['costAmount'] as num?)?.toDouble(),
        isAcceptingVotes:
            j['isAcceptingVotes'] as bool? ?? (j['status'] == 'open'),
        linkedMatchId: (j['linkedMatchId'] ?? j['LinkedMatchId'])?.toString(),
        allowGuests: j['allowGuests'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [
        id,
        status,
        hasVoted,
        totalVoters,
        isAcceptingVotes,
        linkedMatchId,
        allowGuests
      ];
}

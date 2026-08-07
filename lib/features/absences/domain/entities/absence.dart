class AbsenceDto {
  final String id;
  final String startDate;
  final String endDate;
  final int absenceType;
  final String absenceTypeName;
  final String? description;
  final String createdAt;
  final String? playerId;
  final String? playerName;
  final bool isGoalkeeper;

  const AbsenceDto({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.absenceType,
    required this.absenceTypeName,
    this.description,
    required this.createdAt,
    this.playerId,
    this.playerName,
    this.isGoalkeeper = false,
  });

  factory AbsenceDto.fromJson(Map<String, dynamic> json) => AbsenceDto(
        id: (json['id'] ?? json['Id']).toString(),
        startDate: (json['startDate'] ?? json['StartDate']).toString(),
        endDate: (json['endDate'] ?? json['EndDate']).toString(),
        absenceType:
            json['absenceType'] as int? ?? json['AbsenceType'] as int? ?? 0,
        absenceTypeName:
            (json['absenceTypeName'] ?? json['AbsenceTypeName'] ?? '')
                .toString(),
        description:
            json['description'] as String? ?? json['Description'] as String?,
        createdAt: (json['createdAt'] ?? json['CreatedAt'] ?? '').toString(),
        playerId: (json['playerId'] ?? json['PlayerId'])?.toString(),
        playerName: (json['playerName'] ?? json['PlayerName'])?.toString(),
        isGoalkeeper:
            (json['isGoalkeeper'] ?? json['IsGoalkeeper'] ?? false) as bool? ??
                false,
      );
}

class CreateAbsenceDto {
  final String startDate;
  final String endDate;
  final int absenceType;
  final String? description;

  const CreateAbsenceDto({
    required this.startDate,
    required this.endDate,
    required this.absenceType,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'startDate': startDate,
        'endDate': endDate,
        'absenceType': absenceType,
        if (description != null && description!.isNotEmpty)
          'description': description,
      };
}

class PagedAbsences {
  final List<AbsenceDto> items;
  final int total;
  final int page;

  const PagedAbsences({
    required this.items,
    required this.total,
    required this.page,
  });

  static const empty = PagedAbsences(items: [], total: 0, page: 1);

  factory PagedAbsences.fromJson(dynamic node, {int fallbackPage = 1}) {
    if (node is! Map) return PagedAbsences.empty;
    final rawItems = node['items'] ?? node['Items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(AbsenceDto.fromJson)
            .toList()
        : <AbsenceDto>[];
    return PagedAbsences(
      items: items,
      total: node['total'] as int? ?? node['Total'] as int? ?? items.length,
      page: node['page'] as int? ?? node['Page'] as int? ?? fallbackPage,
    );
  }
}

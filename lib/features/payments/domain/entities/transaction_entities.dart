// type: 0 = entrada, 1 = saída
class TransactionDto {
  final String id;
  final int type; // 0=entrada, 1=saída
  final double amount;
  final String description;
  final String date;
  final int? category;
  final bool isAutomatic;
  final String? playerName;
  final String createdAt;

  const TransactionDto({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    this.category,
    required this.isAutomatic,
    this.playerName,
    required this.createdAt,
  });

  bool get isIncome => type == 0;

  factory TransactionDto.fromJson(Map<String, dynamic> j) => TransactionDto(
        id: (j['id'] ?? '').toString(),
        type: (j['type'] as num?)?.toInt() ?? 0,
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        description: (j['description'] ?? '').toString(),
        date: (j['date'] ?? '').toString(),
        category: (j['category'] as num?)?.toInt(),
        isAutomatic: j['isAutomatic'] as bool? ?? false,
        playerName: j['playerName'] as String?,
        createdAt: (j['createdAt'] ?? '').toString(),
      );
}

class TransactionMonthSummaryDto {
  final int year;
  final int month;
  final double totalIncome;
  final double totalExpense;
  final double netBalance;
  final double accumulatedBalance;

  const TransactionMonthSummaryDto({
    required this.year,
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
    required this.accumulatedBalance,
  });

  factory TransactionMonthSummaryDto.fromJson(Map<String, dynamic> j) =>
      TransactionMonthSummaryDto(
        year: (j['year'] as num?)?.toInt() ?? 0,
        month: (j['month'] as num?)?.toInt() ?? 0,
        totalIncome: (j['totalIncome'] as num?)?.toDouble() ?? 0,
        totalExpense: (j['totalExpense'] as num?)?.toDouble() ?? 0,
        netBalance: (j['netBalance'] as num?)?.toDouble() ?? 0,
        accumulatedBalance: (j['accumulatedBalance'] as num?)?.toDouble() ?? 0,
      );
}

class PendingTotalsDto {
  final double totalMonthlyPending;
  final double totalExtraChargesPending;
  final double grandTotal;

  const PendingTotalsDto({
    required this.totalMonthlyPending,
    required this.totalExtraChargesPending,
    required this.grandTotal,
  });

  factory PendingTotalsDto.fromJson(Map<String, dynamic> j) => PendingTotalsDto(
        totalMonthlyPending:
            (j['totalMonthlyPending'] as num?)?.toDouble() ?? 0,
        totalExtraChargesPending:
            (j['totalExtraChargesPending'] as num?)?.toDouble() ?? 0,
        grandTotal: (j['grandTotal'] as num?)?.toDouble() ?? 0,
      );
}

class CreateTransactionDto {
  final int type;
  final double amount;
  final String description;
  final String date;
  final int? category;

  const CreateTransactionDto({
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    this.category,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'amount': amount,
        'description': description,
        'date': date,
        if (category != null) 'category': category,
      };
}

import '../../../../core/utils/date_utils.dart';

// ── Pagamento em lote do próprio usuário ────────────────────────────────────

class PendingPaymentItem {
  final String id;
  final String description;
  final double amount;
  final double discount;
  final double finalAmount;
  final int type; // 0 = mensalidade, 1 = cobrança extra
  final int? year;
  final int? month;
  final String? chargeId;
  final bool isPaid;

  const PendingPaymentItem({
    required this.id,
    required this.description,
    required this.amount,
    required this.discount,
    required this.finalAmount,
    required this.type,
    this.year,
    this.month,
    this.chargeId,
    required this.isPaid,
  });

  factory PendingPaymentItem.fromJson(Map<String, dynamic> json) {
    T? value<T>(String camel, String pascal) =>
        (json[camel] ?? json[pascal]) as T?;

    return PendingPaymentItem(
      id: value<String>('id', 'Id') ?? '',
      description: value<String>('description', 'Description') ?? '',
      amount: (json['amount'] ?? json['Amount'] as num? ?? 0).toDouble(),
      discount: (json['discount'] ?? json['Discount'] as num? ?? 0).toDouble(),
      finalAmount:
          (json['finalAmount'] ?? json['FinalAmount'] as num? ?? 0).toDouble(),
      type: value<int>('type', 'Type') ?? 0,
      year: value<int>('year', 'Year'),
      month: value<int>('month', 'Month'),
      chargeId: value<String>('chargeId', 'ChargeId'),
      isPaid: value<bool>('isPaid', 'IsPaid') ?? false,
    );
  }

  Map<String, dynamic> toPaidRequest() => {
        'type': type,
        'year': year,
        'month': month,
        'chargeId': chargeId,
        'isPaid': true,
      };
}

// ── Mensalidades ──────────────────────────────────────────────────────────────

class MonthlyCell {
  final int month;
  final int status; // 0 = pendente, 1 = pago
  final double amount;
  final double discount;
  final String? discountReason;
  final String? paidAt;
  final bool hasProof;
  final String? proofFileName;

  const MonthlyCell({
    required this.month,
    required this.status,
    required this.amount,
    required this.discount,
    this.discountReason,
    this.paidAt,
    required this.hasProof,
    this.proofFileName,
  });

  bool get isPaid => status == 1;

  factory MonthlyCell.fromJson(Map<String, dynamic> j) => MonthlyCell(
        month: j['month'] as int,
        status: j['status'] as int,
        amount: (j['amount'] as num).toDouble(),
        discount: (j['discount'] as num? ?? 0).toDouble(),
        discountReason: j['discountReason'] as String?,
        paidAt: j['paidAt'] as String?,
        hasProof: j['hasProof'] as bool? ?? false,
        proofFileName: j['proofFileName'] as String?,
      );
}

class PlayerRow {
  final String playerId;
  final String playerName;
  final List<MonthlyCell> months;

  /// 1–5 star evaluation (guestStarRating field from the player record).
  final int? starRating;
  final bool isGoalkeeper;

  const PlayerRow({
    required this.playerId,
    required this.playerName,
    required this.months,
    this.starRating,
    this.isGoalkeeper = false,
  });

  factory PlayerRow.fromJson(Map<String, dynamic> j) => PlayerRow(
        playerId: j['playerId'] as String,
        playerName: j['playerName'] as String,
        months: (j['months'] as List? ?? [])
            .map((e) => MonthlyCell.fromJson(e as Map<String, dynamic>))
            .toList(),
        starRating: j['guestStarRating'] as int? ?? j['starRating'] as int?,
        isGoalkeeper: j['isGoalkeeper'] as bool? ?? false,
      );
}

class MonthlyGrid {
  final int year;
  final double? monthlyFee;
  final double? goalkeeperMonthlyFee;
  final List<PlayerRow> players;

  const MonthlyGrid({
    required this.year,
    this.monthlyFee,
    this.goalkeeperMonthlyFee,
    required this.players,
  });

  factory MonthlyGrid.fromJson(Map<String, dynamic> j) => MonthlyGrid(
        year: j['year'] as int,
        monthlyFee: (j['monthlyFee'] as num?)?.toDouble(),
        goalkeeperMonthlyFee: (j['goalkeeperMonthlyFee'] as num?)?.toDouble(),
        players: (j['players'] as List? ?? [])
            .map((e) => PlayerRow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ── Cobranças extras ──────────────────────────────────────────────────────────

class ExtraChargePayment {
  final String playerId;
  final String playerName;
  final bool isGoalkeeper;
  final double amount;
  final double discount;
  final double finalAmount;
  final String? discountReason;
  final int status; // 0 = pendente, 1 = pago
  final String? paidAt;
  final bool hasProof;
  final String? proofFileName;

  const ExtraChargePayment({
    required this.playerId,
    required this.playerName,
    this.isGoalkeeper = false,
    required this.amount,
    required this.discount,
    required this.finalAmount,
    this.discountReason,
    required this.status,
    this.paidAt,
    required this.hasProof,
    this.proofFileName,
  });

  bool get isPaid => status == 1;

  factory ExtraChargePayment.fromJson(Map<String, dynamic> j) =>
      ExtraChargePayment(
        playerId: j['playerId'] as String,
        playerName: j['playerName'] as String,
        isGoalkeeper: j['isGoalkeeper'] as bool? ?? false,
        amount: (j['amount'] as num).toDouble(),
        discount: (j['discount'] as num? ?? 0).toDouble(),
        finalAmount: (j['finalAmount'] as num).toDouble(),
        discountReason: j['discountReason'] as String?,
        status: j['status'] as int,
        paidAt: j['paidAt'] as String?,
        hasProof: j['hasProof'] as bool? ?? false,
        proofFileName: j['proofFileName'] as String?,
      );
}

class ExtraCharge {
  final String id;
  final String name;
  final String? description;
  final double amount;
  final String? dueDate;
  final String createdAt;
  final bool isCancelled;
  final List<ExtraChargePayment> payments;

  const ExtraCharge({
    required this.id,
    required this.name,
    this.description,
    required this.amount,
    this.dueDate,
    required this.createdAt,
    required this.isCancelled,
    required this.payments,
  });

  bool get isFinalized =>
      !isCancelled && payments.isNotEmpty && payments.every((p) => p.isPaid);

  int get year => AppDateUtils.parseOrNow(createdAt).year;
  int get month => AppDateUtils.parseOrNow(createdAt).month;

  factory ExtraCharge.fromJson(Map<String, dynamic> j) => ExtraCharge(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        amount: (j['amount'] as num).toDouble(),
        dueDate: j['dueDate'] as String?,
        createdAt: j['createdAt'] as String,
        isCancelled: j['isCancelled'] as bool? ?? false,
        payments: (j['payments'] as List? ?? [])
            .map((e) => ExtraChargePayment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ── Resumo financeiro (dashboard) ─────────────────────────────────────────────

class PaymentSummary {
  final int pendingMonthlyCount;
  final int pendingExtraCount;
  final double totalPendingAmount;
  final int paymentMode; // 0=Monthly, 1=PerGame

  const PaymentSummary({
    required this.pendingMonthlyCount,
    required this.pendingExtraCount,
    required this.totalPendingAmount,
    required this.paymentMode,
  });

  factory PaymentSummary.fromJson(Map<String, dynamic> j) => PaymentSummary(
        pendingMonthlyCount:
            (j['pendingMonthlyCount'] ?? j['PendingMonthlyCount']) as int? ?? 0,
        pendingExtraCount:
            (j['pendingExtraCount'] ?? j['PendingExtraCount']) as int? ?? 0,
        totalPendingAmount:
            ((j['totalPendingAmount'] ?? j['TotalPendingAmount']) as num? ?? 0)
                .toDouble(),
        paymentMode: (j['paymentMode'] ?? j['PaymentMode']) as int? ?? 0,
      );
}

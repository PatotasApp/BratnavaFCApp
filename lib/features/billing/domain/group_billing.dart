/// Plano da patota (pacotes avulsos de 1, 3, 6 ou 12 meses que somam ao
/// vencimento). Espelha `GroupBillingStatusDto` da API.
///
/// Só admin e financeiro da patota recebem isto; para o jogador comum a API
/// responde 403 e o app não mostra nada de cobrança.
class GroupBilling {
  final String groupId;

  /// "lifetime" | "trial" | "active" | "grace" | "expired".
  final String status;
  final bool isLifetime;

  /// Último dia com acesso (calendário de Brasília), "yyyy-MM-dd".
  final String? accessEndsOn;
  final int? daysRemaining;
  final bool trialGranted;
  final bool isReadOnly;
  final bool enforcementEnabled;
  final int graceDays;
  final bool showBanner;
  final bool canPurchase;
  final String? purchaseBlockedReason;
  final List<BillingPackage> packages;
  final bool simulatedPurchasesEnabled;
  final List<BillingHistoryItem> history;
  final String termsUrl;
  final String privacyUrl;

  const GroupBilling({
    required this.groupId,
    required this.status,
    required this.isLifetime,
    required this.accessEndsOn,
    required this.daysRemaining,
    required this.trialGranted,
    required this.isReadOnly,
    required this.enforcementEnabled,
    required this.graceDays,
    required this.showBanner,
    required this.canPurchase,
    required this.purchaseBlockedReason,
    required this.packages,
    required this.simulatedPurchasesEnabled,
    required this.history,
    required this.termsUrl,
    required this.privacyUrl,
  });

  factory GroupBilling.fromJson(Map<String, dynamic> j) => GroupBilling(
        groupId: (j['groupId'] ?? '').toString(),
        status: (j['status'] ?? 'trial').toString(),
        isLifetime: j['isLifetime'] == true,
        accessEndsOn: j['accessEndsOn'] as String?,
        daysRemaining: (j['daysRemaining'] as num?)?.toInt(),
        trialGranted: j['trialGranted'] != false,
        isReadOnly: j['isReadOnly'] == true,
        enforcementEnabled: j['enforcementEnabled'] == true,
        graceDays: (j['graceDays'] as num?)?.toInt() ?? 0,
        showBanner: j['showBanner'] == true,
        canPurchase: j['canPurchase'] == true,
        purchaseBlockedReason: j['purchaseBlockedReason'] as String?,
        packages: ((j['products'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => BillingPackage.fromJson(e.cast<String, dynamic>()))
            .toList(),
        simulatedPurchasesEnabled: j['simulatedPurchasesEnabled'] == true,
        history: ((j['history'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => BillingHistoryItem.fromJson(e.cast<String, dynamic>()))
            .toList(),
        termsUrl: (j['termsUrl'] ?? '').toString(),
        privacyUrl: (j['privacyUrl'] ?? '').toString(),
      );

  bool get isExpired => status == 'expired';
  bool get isGrace => status == 'grace';

  /// Pacotes da loja do aparelho (sem os simulados).
  List<BillingPackage> get storePackages =>
      packages.where((p) => !p.isSimulated).toList();

  List<BillingPackage> get simulatedPackages =>
      packages.where((p) => p.isSimulated).toList();

  /// "Em teste", "Paga", "Vencida"...
  String get statusLabel => switch (status) {
        'lifetime' => 'Plano vitalício',
        'trial' => trialGranted ? 'Teste grátis' : 'Sem teste grátis',
        'active' => 'Paga',
        'grace' => 'Vencida (tolerância)',
        _ => 'Vencida',
      };

  /// Frase do vencimento, sem ambiguidade: dia e quanto falta.
  String get dueText {
    if (isLifetime) return 'Sem vencimento';
    final date = formatDay(accessEndsOn);
    final d = daysRemaining ?? 0;
    if (d > 1) return 'Vence em $date · faltam $d dias';
    if (d == 1) return 'Vence amanhã ($date)';
    if (d == 0) return 'Vence hoje ($date)';
    if (d == -1) return 'Venceu ontem ($date)';
    return 'Venceu em $date · há ${-d} dias';
  }

  /// Texto da faixa do Dashboard.
  String get bannerText {
    final d = daysRemaining ?? 0;
    if (isExpired) {
      return enforcementEnabled
          ? 'O plano da patota venceu. Ela está em modo somente leitura.'
          : 'O plano da patota venceu. Pague para continuar usando tudo.';
    }
    if (isGrace) {
      return 'O plano da patota venceu. Pague para não perder o acesso.';
    }
    if (d <= 0) return 'O plano da patota vence hoje.';
    if (d == 1) return 'O plano da patota vence amanhã.';
    return 'O plano da patota vence em $d dias.';
  }
}

class BillingPackage {
  /// "apple" | "google" | "simulated".
  final String store;
  final String productId;
  final int months;
  final double referencePrice;

  /// Até quando a patota fica paga se comprar agora (yyyy-MM-dd).
  final String extendsUntilOn;

  const BillingPackage({
    required this.store,
    required this.productId,
    required this.months,
    required this.referencePrice,
    required this.extendsUntilOn,
  });

  factory BillingPackage.fromJson(Map<String, dynamic> j) => BillingPackage(
        store: (j['store'] ?? '').toString(),
        productId: (j['productId'] ?? '').toString(),
        months: (j['months'] as num?)?.toInt() ?? 1,
        referencePrice: (j['referencePrice'] as num?)?.toDouble() ?? 0,
        extendsUntilOn: (j['extendsUntilOn'] ?? '').toString(),
      );

  bool get isSimulated => store == 'simulated';

  String get monthsLabel => months == 1 ? '1 mês' : '$months meses';
}

class BillingHistoryItem {
  final DateTime purchasedAt;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final int months;
  final String store;

  /// "confirmed" | "pending" | "refunded".
  final String state;
  final String? payerName;
  final double? price;
  final String? currency;

  const BillingHistoryItem({
    required this.purchasedAt,
    required this.periodStart,
    required this.periodEnd,
    required this.months,
    required this.store,
    required this.state,
    required this.payerName,
    required this.price,
    required this.currency,
  });

  factory BillingHistoryItem.fromJson(Map<String, dynamic> j) =>
      BillingHistoryItem(
        purchasedAt: parseApiDate(j['purchasedAt']) ?? DateTime.now(),
        periodStart: parseApiDate(j['periodStart']),
        periodEnd: parseApiDate(j['periodEnd']),
        months: (j['months'] as num?)?.toInt() ?? 1,
        store: (j['store'] ?? '').toString(),
        state: (j['state'] ?? 'confirmed').toString(),
        payerName: j['payerName'] as String?,
        price: (j['price'] as num?)?.toDouble(),
        currency: j['currency'] as String?,
      );

  String get stateLabel => switch (state) {
        'refunded' => 'Reembolsado',
        'pending' => 'Pagamento pendente',
        _ => 'Pago',
      };

  String get storeLabel => billingStoreLabel(store);
}

String billingStoreLabel(String store) => switch (store) {
      'apple' => 'App Store',
      'google' => 'Google Play',
      'simulated' => 'Compra simulada',
      _ => store,
    };

/// A API devolve UTC sem o "Z"; sem isto o Dart leria como hora local.
DateTime? parseApiDate(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  final hasZone = RegExp(r'([zZ]|[+-]\d{2}:?\d{2})$').hasMatch(value);
  return DateTime.tryParse(hasZone ? value : '${value}Z');
}

/// "2026-12-06" → "06/12/2026".
String formatDay(String? isoDay) {
  if (isoDay == null || isoDay.length < 10) return '—';
  final p = isoDay.substring(0, 10).split('-');
  return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : isoDay;
}

/// Data no horário de Brasília (UTC-3 fixo, como a API), "dd/MM/yyyy".
String formatBrasiliaDate(DateTime utc) {
  final b = utc.toUtc().subtract(const Duration(hours: 3));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(b.day)}/${two(b.month)}/${b.year}';
}

String formatBrl(double value) {
  final fixed = value.toStringAsFixed(2).split('.');
  final intPart =
      fixed[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return 'R\$ $intPart,${fixed[1]}';
}

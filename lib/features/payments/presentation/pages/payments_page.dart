import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../group_settings/presentation/providers/group_settings_provider.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../../../shared/presentation/widgets/app_page_header.dart';
import '../../data/datasources/payments_remote_datasource.dart';
import '../../data/datasources/transactions_remote_datasource.dart';
import '../../domain/entities/payment_entities.dart';
import '../../domain/entities/transaction_entities.dart';
import '../providers/payments_provider.dart';
import '../widgets/monthly_payment_sheet.dart';
import '../widgets/extra_payment_sheet.dart';
import '../widgets/create_extra_charge_sheet.dart';
import '../widgets/bulk_discount_sheet.dart';

const _months = [
  'Jan',
  'Fev',
  'Mar',
  'Abr',
  'Mai',
  'Jun',
  'Jul',
  'Ago',
  'Set',
  'Out',
  'Nov',
  'Dez',
];

class PaymentsPage extends ConsumerStatefulWidget {
  const PaymentsPage({super.key});

  @override
  ConsumerState<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends ConsumerState<PaymentsPage>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;
  int _year = DateTime.now().year;
  int _extraYear = DateTime.now().year;
  int _extraMonth = DateTime.now().month;
  int _paymentMode = 0; // 0=Monthly, 1=PerGame
  bool _loadingMode = true;
  bool _loadingModeRequest = false;
  String? _loadedGroupId;

  // ── Caixa ────────────────────────────────────────────────────────────────
  String _caixaSubTab = 'mes'; // 'mes' | 'geral'
  int _txYear = DateTime.now().year;
  int _txMonth = DateTime.now().month;

  String? get _groupId {
    final acc = ref.read(accountStoreProvider).activeAccount;
    final player = ref.read(activePlayerProvider);
    return acc?.activeGroupId ?? player?.groupId;
  }

  // Somente financeiro enxerga as pendências da patota inteira.
  // Admin vê apenas as próprias pendências, igual aos demais jogadores.
  bool get _isPaymentAdmin {
    final acc = ref.read(accountStoreProvider).activeAccount;
    final gid = _groupId;
    if (acc == null || gid == null) return false;
    return acc.isGroupFinanceiro(gid);
  }

  PaymentsRemoteDataSource get _ds => ref.read(paymentsDsProvider);

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadPaymentMode();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _ensureTabControllerLength(int length) {
    if (_tabCtrl.length == length) return;
    final index = _tabCtrl.index.clamp(0, length - 1).toInt();
    // O TabBar/TabBarView pode ainda estar finalizando a renderização com o
    // controlador anterior. Não o descarte aqui: a instância atual será
    // descartada normalmente no dispose da página.
    _tabCtrl = TabController(length: length, vsync: this, initialIndex: index);
  }

  Future<void> _loadPaymentMode() async {
    if (_loadingModeRequest) return;
    _loadingModeRequest = true;
    final gid = _groupId;
    if (gid == null) {
      if (mounted) setState(() => _loadingMode = false);
      _loadingModeRequest = false;
      return;
    }
    try {
      final ds = ref.read(groupSettingsDsProvider);
      final settings = await ds.fetchGroupSettings(gid);
      if (mounted && _groupId == gid) {
        final tabLength =
            (settings.paymentMode == 0 ? 2 : 1) + (_isPaymentAdmin ? 1 : 0);
        _ensureTabControllerLength(tabLength);
        setState(() {
          _loadedGroupId = gid;
          _paymentMode = settings.paymentMode;
          _loadingMode = false;
        });
      }
    } catch (_) {
      if (mounted && _groupId == gid) {
        _ensureTabControllerLength(
            (_paymentMode == 0 ? 2 : 1) + (_isPaymentAdmin ? 1 : 0));
        setState(() {
          _loadedGroupId = gid;
          _loadingMode = false;
        });
      }
    } finally {
      _loadingModeRequest = false;
    }
  }

  void _refreshMonthly() {
    final gid = _groupId;
    if (gid == null) return;
    ref.invalidate(monthlyGridProvider((groupId: gid, year: _year)));
    ref.invalidate(myMonthlyRowProvider((groupId: gid, year: _year)));
  }

  void _refreshExtra() {
    final gid = _groupId;
    if (gid == null) return;
    ref.invalidate(extraChargesProvider(gid));
    ref.invalidate(myExtraChargesProvider(gid));
  }

  // ── Abrir sheet de pagamento mensal ──────────────────────────────────────

  Future<void> _openMonthlySheet(
      BuildContext ctx, PlayerRow row, int month) async {
    final gid = _groupId;
    if (gid == null) return;
    final isPaymentAdmin = _isPaymentAdmin;
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => MonthlyPaymentSheet(
        groupId: gid,
        row: row,
        month: month,
        isAdmin: isPaymentAdmin,
        onSubmit: (dto) {
          if (isPaymentAdmin) return _ds.upsertMonthly(gid, dto);
          return _ds.paySelected(gid, {
            'items': [
              {
                'type': 0,
                'year': dto['year'],
                'month': dto['month'],
                'chargeId': null,
                'isPaid': dto['status'] == 1,
              },
            ],
          });
        },
        onSaveRating: (stars) => _ds.updatePlayerRating(row.playerId, stars),
        onSaved: _refreshMonthly,
      ),
    );
  }

  // ── Abrir sheet de cobrança extra ─────────────────────────────────────────

  Future<void> _openExtraSheet(
      BuildContext ctx, ExtraCharge charge, ExtraChargePayment payment) async {
    final gid = _groupId;
    if (gid == null) return;
    final isPaymentAdmin = _isPaymentAdmin;
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => ExtraPaymentSheet(
        groupId: gid,
        charge: charge,
        payment: payment,
        isAdmin: isPaymentAdmin,
        onSubmit: (dto) {
          if (isPaymentAdmin) {
            return _ds.upsertExtraChargePayment(
                gid, charge.id, payment.playerId, dto);
          }
          return _ds.paySelected(gid, {
            'items': [
              {
                'type': 1,
                'year': null,
                'month': null,
                'chargeId': charge.id,
                'isPaid': dto['status'] == 1,
              },
            ],
          });
        },
        onSaved: _refreshExtra,
      ),
    );
  }

  // ── Criar cobrança extra ──────────────────────────────────────────────────

  Future<void> _openCreateSheet(
      BuildContext ctx, List<PlayerRow> players) async {
    final gid = _groupId;
    if (gid == null) return;
    final playerList =
        players.map((p) => (id: p.playerId, name: p.playerName)).toList();
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => CreateExtraChargeSheet(
        players: playerList,
        onSubmit: (dto) => _ds.createExtraCharge(gid, dto),
        onSaved: _refreshExtra,
      ),
    );
  }

  // ── Bulk discount ─────────────────────────────────────────────────────────

  Future<void> _openBulkSheet(BuildContext ctx, ExtraCharge charge) async {
    final gid = _groupId;
    if (gid == null) return;
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => BulkDiscountSheet(
        groupId: gid,
        charge: charge,
        onSubmit: (dto) => _ds.bulkDiscountExtraCharge(gid, charge.id, dto),
        onSaved: _refreshExtra,
      ),
    );
  }

  // ── Cancelar cobrança ─────────────────────────────────────────────────────

  Future<void> _cancelCharge(BuildContext ctx, String chargeId) async {
    final gid = _groupId;
    if (gid == null) return;
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar cobrança'),
        content: const Text('Tem certeza que deseja cancelar esta cobrança?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Não')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Sim', style: TextStyle(color: AppColors.rose500)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _ds.cancelExtraCharge(gid, chargeId);
      _refreshExtra();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Cobrança cancelada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao cancelar: $e'),
          backgroundColor: AppColors.rose500,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // ref.watch — reconstrói automaticamente quando activeGroupId muda
    // (ex.: AppTopBar auto-seleciona o grupo logo após o login)
    final account = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    // Fallback: usa o groupId do player ativo se activeGroupId ainda não foi
    // persistido (race condition logo após login com múltiplos grupos)
    // O jogador manda no grupo: `activeGroupId` da conta pode apontar
    // para uma patota sem jogador nosso, e aí toda rota por grupo
    // responde 403. Ver dashboard_page para o diagnóstico completo.
    final groupId = account?.activeGroupId ?? activePlayer?.groupId ?? '';
    final isAdmin = account != null && groupId.isNotEmpty
        ? account.isGroupFinanceiro(groupId)
        : false;

    // Se o groupId acabou de ser resolvido e o paymentMode ainda não foi carregado,
    // dispara o carregamento agora (cobre o caso de login com múltiplos grupos).
    if (groupId.isNotEmpty && _loadingMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPaymentMode());
    }

    if (groupId.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text(
            'Crie ou entre em um grupo',
            style: TextStyle(
                color: isDark ? AppColors.slate400 : AppColors.slate500),
          ),
        ),
      );
    }

    // Permissões e configuração são por patota. Ao trocar de grupo, reduz o
    // número de abas imediatamente (principalmente removendo Caixa) e só então
    // recarrega o modo de cobrança da nova patota. Isso evita exibir por um
    // frame o conteúdo financeiro do grupo anterior.
    _ensureTabControllerLength((_paymentMode == 0 ? 2 : 1) + (isAdmin ? 1 : 0));
    if (_loadedGroupId != groupId && !_loadingModeRequest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _groupId != groupId) return;
        setState(() => _loadingMode = true);
        _loadPaymentMode();
      });
    }

    if (_loadingMode) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverToBoxAdapter(
            child: _buildHeader(),
          ),
        ],
        body: Column(
          key: ValueKey(_tabCtrl),
          children: [
            Container(
              color: isDark ? AppColors.slate900 : AppColors.onDark,
              child: TabBar(
                controller: _tabCtrl,
                tabs: [
                  if (_paymentMode == 0)
                    const Tab(
                      icon: Icon(Icons.calendar_month_outlined, size: 18),
                      text: 'Mensalidades',
                    ),
                  const Tab(
                    icon: Icon(Icons.receipt_long_outlined, size: 18),
                    text: 'Cobranças extras',
                  ),
                  if (isAdmin)
                    const Tab(
                      icon: Icon(Icons.account_balance_outlined, size: 18),
                      text: 'Caixa',
                    ),
                ],
                labelColor: isDark ? AppColors.onDark : AppColors.slate900,
                unselectedLabelColor:
                    isDark ? AppColors.slate500 : AppColors.slate400,
                indicatorColor: isDark ? AppColors.onDark : AppColors.slate900,
                labelStyle:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  if (_paymentMode == 0)
                    _MonthlyTab(
                      groupId: groupId,
                      year: _year,
                      isAdmin: isAdmin,
                      onYearChanged: (y) => setState(() => _year = y),
                      onOpenSheet: (ctx, row, month) =>
                          _openMonthlySheet(ctx, row, month),
                    ),
                  _ExtraTab(
                    groupId: groupId,
                    year: _extraYear,
                    month: _extraMonth,
                    isAdmin: isAdmin,
                    onYearChanged: (y) => setState(() => _extraYear = y),
                    onMonthChanged: (m) => setState(() => _extraMonth = m),
                    onOpenExtraSheet: (ctx, c, p) => _openExtraSheet(ctx, c, p),
                    onCreateSheet: (ctx, players) =>
                        _openCreateSheet(ctx, players),
                    onBulkSheet: (ctx, c) => _openBulkSheet(ctx, c),
                    onCancel: (ctx, id) => _cancelCharge(ctx, id),
                    onRefresh: _refreshExtra,
                  ),
                  if (isAdmin)
                    _CaixaView(
                      groupId: groupId,
                      isDark: isDark,
                      subTab: _caixaSubTab,
                      txYear: _txYear,
                      txMonth: _txMonth,
                      onSubTab: (s) => setState(() => _caixaSubTab = s),
                      onTxYear: (y) => setState(() => _txYear = y),
                      onTxMonth: (m) => setState(() => _txMonth = m),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const AppPageHeader(
      title: 'Pagamentos',
      subtitle: 'Mensalidades, cobranças e caixa',
      icon: Icons.payments_outlined,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CAIXA
// ══════════════════════════════════════════════════════════════════════════════

const _kMonthNames = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];
const _kMonthShort = [
  'Jan',
  'Fev',
  'Mar',
  'Abr',
  'Mai',
  'Jun',
  'Jul',
  'Ago',
  'Set',
  'Out',
  'Nov',
  'Dez',
];
const _kCategoryNames = [
  'Aluguel',
  'Bola',
  'Colete',
  'Árbitro',
  'Transporte',
  'Lanche',
  'Outro',
];

class _CaixaView extends ConsumerStatefulWidget {
  final String groupId;
  final bool isDark;
  final String subTab;
  final int txYear, txMonth;
  final void Function(String) onSubTab;
  final void Function(int) onTxYear;
  final void Function(int) onTxMonth;

  const _CaixaView({
    required this.groupId,
    required this.isDark,
    required this.subTab,
    required this.txYear,
    required this.txMonth,
    required this.onSubTab,
    required this.onTxYear,
    required this.onTxMonth,
  });

  @override
  ConsumerState<_CaixaView> createState() => _CaixaViewState();
}

class _CaixaViewState extends ConsumerState<_CaixaView> {
  List<TransactionDto> _transactions = [];
  List<TransactionMonthSummaryDto> _summaries = [];
  PendingTotalsDto? _pending;
  bool _loading = false;
  String? _error;

  TransactionsRemoteDataSource get _ds => ref.read(transactionsDsProvider);

  @override
  void initState() {
    super.initState();
    // initState é síncrono; usamos addPostFrameCallback para acessar ref
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(_CaixaView old) {
    super.didUpdateWidget(old);
    if (old.subTab != widget.subTab ||
        old.txYear != widget.txYear ||
        old.txMonth != widget.txMonth) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.subTab == 'mes') {
        final results = await Future.wait([
          _ds.getByMonth(widget.groupId, widget.txYear, widget.txMonth),
          _ds.getPendingTotals(widget.groupId),
        ]);
        if (mounted)
          setState(() {
            _transactions = results[0] as List<TransactionDto>;
            _pending = results[1] as PendingTotalsDto?;
          });
      } else {
        final results = await Future.wait([
          _ds.getMonthlySummaries(widget.groupId),
          _ds.getPendingTotals(widget.groupId),
        ]);
        if (mounted)
          setState(() {
            _summaries = results[0] as List<TransactionMonthSummaryDto>;
            _pending = results[1] as PendingTotalsDto?;
          });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addTransaction(int type) async {
    final amtCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var selectedDate = DateTime.now();
    final dateCtrl = TextEditingController(
        text:
            '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}');
    int? category;
    String? validationMessage;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(type == 0 ? '+ Entrada' : '- Saída'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: amtCtrl,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Valor (R\$)', prefixText: 'R\$ ')),
              const SizedBox(height: 12),
              TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Descrição')),
              const SizedBox(height: 12),
              TextField(
                controller: dateCtrl,
                readOnly: true,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(DateTime.now().year + 5),
                  );
                  if (picked == null) return;
                  setS(() {
                    selectedDate = picked;
                    dateCtrl.text =
                        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Data',
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
              ),
              if (type == 1) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  value: category,
                  items: List.generate(
                      _kCategoryNames.length,
                      (i) => DropdownMenuItem(
                          value: i, child: Text(_kCategoryNames[i]))),
                  onChanged: (v) => setS(() => category = v),
                ),
              ],
              if (validationMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  validationMessage!,
                  style: const TextStyle(
                    color: AppColors.rose500,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor:
                      type == 0 ? AppColors.primaryPressed : AppColors.rose500),
              onPressed: () {
                final amount =
                    double.tryParse(amtCtrl.text.trim().replaceAll(',', '.'));
                final message = amount == null || amount <= 0
                    ? 'Informe um valor maior que zero.'
                    : descCtrl.text.trim().isEmpty
                        ? 'Informe uma descrição para o lançamento.'
                        : type == 1 && category == null
                            ? 'Selecione uma categoria para a saída.'
                            : null;
                if (message != null) {
                  setS(() => validationMessage = message);
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final amount = double.tryParse(amtCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) return;
    if (descCtrl.text.trim().isEmpty) return;

    try {
      await _ds.createTransaction(
          widget.groupId,
          CreateTransactionDto(
            type: type,
            amount: amount,
            description: descCtrl.text.trim(),
            date: dateCtrl.text.trim(),
            category: type == 1 ? category : null,
          ));
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro: $e'), backgroundColor: AppColors.rose500));
    }
  }

  Future<void> _deleteTransaction(String id) async {
    try {
      await _ds.deleteTransaction(widget.groupId, id);
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final p = _pending;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Pendências em aberto ─────────────────────────────────────
          if (p != null && p.grandTotal > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.warning : AppColors.amber50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.amber200),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.account_balance_wallet_outlined,
                          size: 15, color: AppColors.amber500),
                      const SizedBox(width: 6),
                      Text('Pendências em aberto',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.amber500,
                          )),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      if (p.totalMonthlyPending > 0)
                        Expanded(
                            child: _PendItem(
                                label: 'Mensalidades',
                                value: p.totalMonthlyPending)),
                      if (p.totalExtraChargesPending > 0)
                        Expanded(
                            child: _PendItem(
                                label: 'Cobranças extras',
                                value: p.totalExtraChargesPending)),
                      Expanded(
                          child: _PendItem(
                              label: 'Total pendente',
                              value: p.grandTotal,
                              bold: true)),
                    ]),
                  ]),
            ),

          // ── Sub-tabs + ações ──────────────────────────────────────────
          Row(children: [
            _SubTabBtn('📅 Mês', 'mes', widget.subTab, isDark,
                () => widget.onSubTab('mes')),
            const SizedBox(width: 6),
            _SubTabBtn('📊 Geral', 'geral', widget.subTab, isDark,
                () => widget.onSubTab('geral')),
          ]),
          const SizedBox(height: 16),

          // ── Sub-tab: Mês ─────────────────────────────────────────────
          if (widget.subTab == 'mes') ...[
            // Navegação ano/mês
            _YearRow(
                year: widget.txYear,
                isDark: isDark,
                onPrev: () => widget.onTxYear(widget.txYear - 1),
                onNext: () => widget.onTxYear(widget.txYear + 1)),
            const SizedBox(height: 8),
            _MonthRow(
                month: widget.txMonth,
                isDark: isDark,
                onMonth: widget.onTxMonth),
            const SizedBox(height: 12),

            // Botões add entrada/saída
            Row(children: [
              Expanded(
                  child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryPressed),
                icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                label: const Text('Entrada'),
                onPressed: () => _addTransaction(0),
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: FilledButton.icon(
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.rose500),
                icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                label: const Text('Saída'),
                onPressed: () => _addTransaction(1),
              )),
            ]),
            const SizedBox(height: 12),

            if (_loading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator()))
            else if (_transactions.isEmpty)
              _EmptyCaixa(
                  isDark: isDark,
                  msg: 'Nenhum lançamento em '
                      '${_kMonthNames[widget.txMonth - 1]}/${widget.txYear}.')
            else ...[
              // Resumo do mês
              _MesSummary(transactions: _transactions, isDark: isDark),
              const SizedBox(height: 12),
              // Lista
              ..._transactions.map((tx) => _TxRow(
                    tx: tx,
                    isDark: isDark,
                    onDelete:
                        tx.isAutomatic ? null : () => _deleteTransaction(tx.id),
                  )),
            ],
          ],

          // ── Sub-tab: Geral ───────────────────────────────────────────
          if (widget.subTab == 'geral') ...[
            if (_loading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator()))
            else if (_summaries.isEmpty)
              _EmptyCaixa(isDark: isDark, msg: 'Nenhum dado disponível.')
            else
              ..._summaries.map((s) => _SummaryRow(summary: s, isDark: isDark)),
          ],
        ],
      ),
    );
  }
}

// ── Widgets auxiliares do Caixa ───────────────────────────────────────────────

class _PendItem extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  const _PendItem(
      {required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppColors.amber500)),
          Text('R\$ ${value.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                color: AppColors.amber500,
              )),
        ],
      );
}

class _SubTabBtn extends StatelessWidget {
  final String label, value, current;
  final bool isDark;
  final VoidCallback onTap;
  const _SubTabBtn(
      this.label, this.value, this.current, this.isDark, this.onTap);

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? (isDark ? AppColors.onDark : AppColors.slate900)
              : (isDark ? AppColors.slate800 : AppColors.onDark),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active
                  ? AppColors.transparent
                  : (isDark ? AppColors.slate700 : AppColors.slate200)),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active
                  ? (isDark ? AppColors.slate900 : AppColors.onDark)
                  : (isDark ? AppColors.slate400 : AppColors.slate600),
            )),
      ),
    );
  }
}

class _YearRow extends StatelessWidget {
  final int year;
  final bool isDark;
  final VoidCallback onPrev, onNext;
  const _YearRow(
      {required this.year,
      required this.isDark,
      required this.onPrev,
      required this.onNext});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
              onTap: onPrev,
              child: Icon(Icons.chevron_left_rounded,
                  size: 20,
                  color: isDark ? AppColors.slate400 : AppColors.slate500)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('$year',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.slate100 : AppColors.slate800,
                )),
          ),
          GestureDetector(
              onTap: onNext,
              child: Icon(Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark ? AppColors.slate400 : AppColors.slate500)),
        ],
      );
}

class _MonthRow extends StatelessWidget {
  final int month;
  final bool isDark;
  final void Function(int) onMonth;
  const _MonthRow(
      {required this.month, required this.isDark, required this.onMonth});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 4,
        runSpacing: 4,
        children: List.generate(12, (i) {
          final active = i + 1 == month;
          return GestureDetector(
            onTap: () => onMonth(i + 1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: active
                    ? (isDark ? AppColors.onDark : AppColors.slate900)
                    : AppColors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: active
                        ? AppColors.transparent
                        : (isDark ? AppColors.slate700 : AppColors.slate200)),
              ),
              child: Text(_kMonthShort[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: active
                        ? (isDark ? AppColors.slate900 : AppColors.onDark)
                        : (isDark ? AppColors.slate400 : AppColors.slate600),
                  )),
            ),
          );
        }),
      );
}

class _MesSummary extends StatelessWidget {
  final List<TransactionDto> transactions;
  final bool isDark;
  const _MesSummary({required this.transactions, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final income =
        transactions.where((t) => t.isIncome).fold(0.0, (s, t) => s + t.amount);
    final expense = transactions
        .where((t) => !t.isIncome)
        .fold(0.0, (s, t) => s + t.amount);
    final net = income - expense;
    return Row(
        children: [
      _SummBox('Entradas', income, AppColors.primaryPressed, isDark),
      const SizedBox(width: 8),
      _SummBox('Saídas', expense, AppColors.rose500, isDark),
      const SizedBox(width: 8),
      _SummBox('Saldo', net,
          net >= 0 ? AppColors.primaryPressed : AppColors.rose500, isDark),
    ].expand((w) => [w]).toList());
  }
}

class _SummBox extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool isDark;
  const _SummBox(this.label, this.value, this.color, this.isDark);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: .2)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 10, color: color)),
            const SizedBox(height: 2),
            Text('R\$ ${value.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
      );
}

class _TxRow extends StatelessWidget {
  final TransactionDto tx;
  final bool isDark;
  final VoidCallback? onDelete;
  const _TxRow({required this.tx, required this.isDark, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isIn = tx.isIncome;
    final color = isIn ? AppColors.primaryPressed : AppColors.rose500;
    final bg = isIn
        ? (isDark ? AppColors.successBackground : AppColors.green50)
        : (isDark ? AppColors.dangerBackground : AppColors.rose50);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Row(children: [
        Icon(
            isIn
                ? Icons.arrow_circle_up_rounded
                : Icons.arrow_circle_down_rounded,
            size: 20,
            color: color),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tx.description,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.onDark : AppColors.slate900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Row(children: [
            Text(
                tx.date.length >= 10
                    ? '${tx.date.substring(8, 10)}/${tx.date.substring(5, 7)}/${tx.date.substring(0, 4)}'
                    : tx.date,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.slate400 : AppColors.slate500)),
            if (tx.category != null &&
                tx.category! < _kCategoryNames.length) ...[
              const SizedBox(width: 6),
              Text(_kCategoryNames[tx.category!],
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.slate500 : AppColors.slate400)),
            ],
            if (tx.isAutomatic) ...[
              const SizedBox(width: 6),
              Text('auto',
                  style: TextStyle(fontSize: 11, color: AppColors.infoLight)),
            ],
          ]),
        ])),
        Text(
          '${isIn ? '+' : '-'} R\$ ${tx.amount.toStringAsFixed(2)}',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: color),
        ),
        if (onDelete != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.close_rounded,
                size: 16,
                color: isDark ? AppColors.slate500 : AppColors.slate400),
          ),
        ],
      ]),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final TransactionMonthSummaryDto summary;
  final bool isDark;
  const _SummaryRow({required this.summary, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final net = summary.netBalance;
    final acc = summary.accumulatedBalance;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.onDark,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
      ),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_kMonthNames[summary.month - 1]} ${summary.year}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.onDark : AppColors.slate900)),
          const SizedBox(height: 3),
          Text(
              'Entradas: R\$ ${summary.totalIncome.toStringAsFixed(2)}   '
              'Saídas: R\$ ${summary.totalExpense.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.slate400 : AppColors.slate500)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('R\$ ${net.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: net >= 0 ? AppColors.primaryPressed : AppColors.rose500,
              )),
          Text('Acc: R\$ ${acc.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AppColors.slate400 : AppColors.slate500)),
        ]),
      ]),
    );
  }
}

class _EmptyCaixa extends StatelessWidget {
  final bool isDark;
  final String msg;
  const _EmptyCaixa({required this.isDark, required this.msg});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 36,
              color: isDark ? AppColors.slate600 : AppColors.slate300),
          const SizedBox(height: 10),
          Text(msg,
              style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.slate400 : AppColors.slate500),
              textAlign: TextAlign.center),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// ABA MENSALIDADES
// ══════════════════════════════════════════════════════════════════════════════

class _MonthlyTab extends ConsumerWidget {
  final String groupId;
  final int year;
  final bool isAdmin;
  final void Function(int) onYearChanged;
  final Future<void> Function(BuildContext, PlayerRow, int) onOpenSheet;

  const _MonthlyTab({
    required this.groupId,
    required this.year,
    required this.isAdmin,
    required this.onYearChanged,
    required this.onOpenSheet,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final icons = GroupIcons.from(
      ref.watch(groupSettingsProvider(groupId)).valueOrNull,
    );

    return isAdmin
        ? _AdminMonthlyView(
            groupId: groupId,
            year: year,
            isDark: isDark,
            onYearChanged: onYearChanged,
            onOpenSheet: onOpenSheet,
            icons: icons,
            ref: ref,
          )
        : _UserMonthlyView(
            groupId: groupId,
            year: year,
            isDark: isDark,
            onYearChanged: onYearChanged,
            onOpenSheet: onOpenSheet,
            ref: ref,
          );
  }
}

// ── Admin: grade completa ─────────────────────────────────────────────────────

class _AdminMonthlyView extends StatefulWidget {
  final String groupId;
  final int year;
  final bool isDark;
  final void Function(int) onYearChanged;
  final Future<void> Function(BuildContext, PlayerRow, int) onOpenSheet;
  final GroupIcons icons;
  final WidgetRef ref;

  const _AdminMonthlyView({
    required this.groupId,
    required this.year,
    required this.isDark,
    required this.onYearChanged,
    required this.onOpenSheet,
    this.icons = GroupIcons.defaults,
    required this.ref,
  });

  @override
  State<_AdminMonthlyView> createState() => _AdminMonthlyViewState();
}

class _AdminMonthlyViewState extends State<_AdminMonthlyView> {
  @override
  Widget build(BuildContext context) {
    final gridAsync = widget.ref.watch(
        monthlyGridProvider((groupId: widget.groupId, year: widget.year)));
    final currentMonth =
        widget.year < DateTime.now().year ? 12 : DateTime.now().month;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Seletor de ano + mensalidade
        Row(children: [
          _YearPicker(
              year: widget.year,
              isDark: widget.isDark,
              onChanged: widget.onYearChanged),
          const SizedBox(width: 12),
          Expanded(
              child: gridAsync.maybeWhen(
            data: (grid) => grid.monthlyFee != null
                ? Wrap(
                    spacing: 8,
                    children: [
                      Text(
                        grid.goalkeeperMonthlyFee != null
                            ? 'Jogador: R\$ ${grid.monthlyFee!.toStringAsFixed(2)}'
                            : 'Mensalidade: R\$ ${grid.monthlyFee!.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: widget.isDark
                              ? AppColors.slate400
                              : AppColors.slate500,
                        ),
                      ),
                      if (grid.goalkeeperMonthlyFee != null)
                        Text(
                          'Goleiro: R\$ ${grid.goalkeeperMonthlyFee!.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.isDark
                                ? AppColors.slate400
                                : AppColors.slate500,
                          ),
                        ),
                    ],
                  )
                : Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.amber50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.amber200),
                    ),
                    child: const Text(
                      'Mensalidade não configurada',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.warningLight),
                    ),
                  ),
            orElse: () => const SizedBox.shrink(),
          )),
        ]),
        const SizedBox(height: 16),

        gridAsync.when(
          loading: () => const Center(
              child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(),
          )),
          error: (e, _) =>
              _ErrorState(extractDioError(e), isDark: widget.isDark),
          data: (grid) {
            if (grid.players.isEmpty) {
              return _EmptyState(
                icon: Icons.group_outlined,
                title: 'Nenhum mensalista encontrado',
                sub:
                    'Jogadores sem conta vinculada ou convidados não aparecem aqui.',
                isDark: widget.isDark,
              );
            }
            return _MonthlyGrid(
              grid: grid,
              currentMonth: currentMonth,
              isDark: widget.isDark,
              onTap: (row, month) => widget.onOpenSheet(context, row, month),
              icons: widget.icons,
            );
          },
        ),
      ],
    );
  }
}

// ── User: só a linha do próprio jogador ──────────────────────────────────────

class _UserMonthlyView extends StatelessWidget {
  final String groupId;
  final int year;
  final bool isDark;
  final void Function(int) onYearChanged;
  final Future<void> Function(BuildContext, PlayerRow, int) onOpenSheet;
  final WidgetRef ref;

  const _UserMonthlyView({
    required this.groupId,
    required this.year,
    required this.isDark,
    required this.onYearChanged,
    required this.onOpenSheet,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final rowAsync =
        ref.watch(myMonthlyRowProvider((groupId: groupId, year: year)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Text('📅 Minhas mensalidades',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.onDark : AppColors.slate800,
              )),
          const SizedBox(width: 12),
          _YearPicker(year: year, isDark: isDark, onChanged: onYearChanged),
        ]),
        const SizedBox(height: 16),
        rowAsync.when(
          loading: () => const Center(
              child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator())),
          error: (e, _) => _ErrorState(extractDioError(e), isDark: isDark),
          data: (row) {
            if (row == null) {
              return _EmptyState(
                icon: Icons.person_off_outlined,
                title: 'Sem jogador vinculado',
                sub: 'Você não tem um jogador vinculado nesta patota.',
                isDark: isDark,
              );
            }
            final now = DateTime.now();
            final visibleMonths = row.months
                .where((c) => year < now.year || c.month <= now.month)
                .toList();

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.1,
              ),
              itemCount: visibleMonths.length,
              itemBuilder: (ctx, i) {
                final cell = visibleMonths[i];
                final paid = cell.isPaid;
                return GestureDetector(
                  onTap: () => onOpenSheet(ctx, row, cell.month),
                  child: Container(
                    decoration: BoxDecoration(
                      color: paid
                          ? AppColors.green50
                          : AppColors.dangerBackgroundLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: paid ? AppColors.green200 : AppColors.rose200,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_months[cell.month - 1],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.slate200
                                  : AppColors.slate700,
                            )),
                        const SizedBox(height: 4),
                        Icon(
                          paid
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          size: 20,
                          color: paid ? AppColors.green500 : AppColors.rose400,
                        ),
                        if (cell.amount > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            'R\$ ${cell.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppColors.slate400
                                  : AppColors.slate500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// ── Grade tabular (admin) ─────────────────────────────────────────────────────

class _MonthlyGrid extends StatelessWidget {
  final MonthlyGrid grid;
  final int currentMonth;
  final bool isDark;
  final void Function(PlayerRow, int) onTap;
  final GroupIcons icons;

  const _MonthlyGrid({
    required this.grid,
    required this.currentMonth,
    required this.isDark,
    required this.onTap,
    this.icons = GroupIcons.defaults,
  });

  @override
  Widget build(BuildContext context) {
    final border = isDark ? AppColors.slate700 : AppColors.slate200;
    final headerBg = isDark ? AppColors.slate800 : AppColors.slate50;
    final rowHover =
        isDark ? AppColors.slate800.withValues(alpha: .4) : AppColors.slate50;
    final txtMuted = isDark ? AppColors.slate500 : AppColors.slate300;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(headerBg),
            dataRowMinHeight: 48,
            dataRowMaxHeight: 48,
            columnSpacing: 8,
            horizontalMargin: 12,
            columns: [
              DataColumn(
                label: Text('Jogador',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.slate400 : AppColors.slate600,
                    )),
              ),
              for (var i = 0; i < 12; i++)
                DataColumn(
                  label: Text(
                    _months[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: i + 1 <= currentMonth
                          ? (isDark ? AppColors.slate400 : AppColors.slate500)
                          : txtMuted,
                    ),
                  ),
                ),
            ],
            rows: grid.players.map((row) {
              return DataRow(
                color: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.hovered) ? rowHover : null,
                ),
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PlayerNameWithIcon(
                          name: row.playerName,
                          icons: icons,
                          isGoalkeeper: row.isGoalkeeper,
                          iconSize: 11,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.slate100
                                : AppColors.slate800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (var m = 1; m <= 12; m++) ...[
                    () {
                      final cell =
                          row.months.where((c) => c.month == m).firstOrNull;
                      if (cell == null) {
                        return DataCell(
                          Text('—',
                              style: TextStyle(fontSize: 12, color: txtMuted)),
                        );
                      }
                      final paid = cell.isPaid;
                      return DataCell(
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: paid ? AppColors.green100 : AppColors.rose50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            paid
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            size: 16,
                            color: paid
                                ? AppColors.primaryPressed
                                : AppColors.rose400,
                          ),
                        ),
                        onTap: () => onTap(row, m),
                      );
                    }(),
                  ],
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ABA COBRANÇAS EXTRAS
// ══════════════════════════════════════════════════════════════════════════════

class _ExtraTab extends ConsumerWidget {
  final String groupId;
  final int year;
  final int month;
  final bool isAdmin;
  final void Function(int) onYearChanged;
  final void Function(int) onMonthChanged;
  final Future<void> Function(BuildContext, ExtraCharge, ExtraChargePayment)
      onOpenExtraSheet;
  final Future<void> Function(BuildContext, List<PlayerRow>) onCreateSheet;
  final Future<void> Function(BuildContext, ExtraCharge) onBulkSheet;
  final Future<void> Function(BuildContext, String) onCancel;
  final VoidCallback onRefresh;

  const _ExtraTab({
    required this.groupId,
    required this.year,
    required this.month,
    required this.isAdmin,
    required this.onYearChanged,
    required this.onMonthChanged,
    required this.onOpenExtraSheet,
    required this.onCreateSheet,
    required this.onBulkSheet,
    required this.onCancel,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final icons = GroupIcons.from(
      ref.watch(groupSettingsProvider(groupId)).valueOrNull,
    );

    if (isAdmin) {
      final chargesAsync = ref.watch(extraChargesProvider(groupId));
      // Precisamos da grade mensal para obter a lista de jogadores
      final gridAsync = ref.watch(
          monthlyGridProvider((groupId: groupId, year: DateTime.now().year)));

      return chargesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(extractDioError(e), isDark: isDark),
        data: (charges) {
          final players = gridAsync.valueOrNull?.players ?? [];
          return _AdminExtraView(
            groupId: groupId,
            charges: charges,
            players: players,
            year: year,
            month: month,
            isDark: isDark,
            icons: icons,
            onYearChanged: onYearChanged,
            onMonthChanged: onMonthChanged,
            onOpenSheet: (ctx, c, p) => onOpenExtraSheet(ctx, c, p),
            onCreateSheet: (ctx) => onCreateSheet(ctx, players),
            onBulkSheet: (ctx, c) => onBulkSheet(ctx, c),
            onCancel: (ctx, id) => onCancel(ctx, id),
            onRefresh: onRefresh,
          );
        },
      );
    } else {
      final chargesAsync = ref.watch(myExtraChargesProvider(groupId));
      return chargesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(extractDioError(e), isDark: isDark),
        data: (charges) => _UserExtraView(
          charges: charges,
          year: year,
          month: month,
          isDark: isDark,
          onYearChanged: onYearChanged,
          onMonthChanged: onMonthChanged,
          onOpenSheet: (ctx, c, p) => onOpenExtraSheet(ctx, c, p),
        ),
      );
    }
  }
}

// ── Admin: lista de cobranças ─────────────────────────────────────────────────

class _AdminExtraView extends StatefulWidget {
  final String groupId;
  final List<ExtraCharge> charges;
  final List<PlayerRow> players;
  final int year;
  final int month;
  final bool isDark;
  final GroupIcons icons;
  final void Function(int) onYearChanged;
  final void Function(int) onMonthChanged;
  final Future<void> Function(BuildContext, ExtraCharge, ExtraChargePayment)
      onOpenSheet;
  final Future<void> Function(BuildContext) onCreateSheet;
  final Future<void> Function(BuildContext, ExtraCharge) onBulkSheet;
  final Future<void> Function(BuildContext, String) onCancel;
  final VoidCallback onRefresh;

  const _AdminExtraView({
    required this.groupId,
    required this.charges,
    required this.players,
    required this.year,
    required this.month,
    required this.isDark,
    required this.icons,
    required this.onYearChanged,
    required this.onMonthChanged,
    required this.onOpenSheet,
    required this.onCreateSheet,
    required this.onBulkSheet,
    required this.onCancel,
    required this.onRefresh,
  });

  @override
  State<_AdminExtraView> createState() => _AdminExtraViewState();
}

class _AdminExtraViewState extends State<_AdminExtraView> {
  final Set<String> _expanded = {};

  List<ExtraCharge> get _filtered => widget.charges
      .where((c) => c.year == widget.year && c.month == widget.month)
      .toList();

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final current = filtered.where((c) => !c.isFinalized).toList();
    final finalized = filtered.where((c) => c.isFinalized).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Nova cobrança e seletor de ano
        Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => widget.onCreateSheet(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Nova cobrança',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      widget.isDark ? AppColors.onDark : AppColors.slate900,
                  foregroundColor:
                      widget.isDark ? AppColors.slate900 : AppColors.onDark,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
              _YearPicker(
                  year: widget.year,
                  isDark: widget.isDark,
                  onChanged: widget.onYearChanged),
            ]),
        const SizedBox(height: 12),

        // Seletor de mês
        _MonthPicker(
          charges: widget.charges,
          year: widget.year,
          selected: widget.month,
          isDark: widget.isDark,
          isAdmin: true,
          onChanged: widget.onMonthChanged,
        ),
        const SizedBox(height: 16),

        if (current.isEmpty && finalized.isEmpty)
          _EmptyState(
            icon: Icons.monetization_on_outlined,
            title:
                'Nenhuma cobrança em ${_months[widget.month - 1]}/${widget.year}',
            sub: '',
            isDark: widget.isDark,
          )
        else ...[
          if (current.isNotEmpty) ...[
            _SectionTitle('📌 Pendentes / Ativas', widget.isDark),
            const SizedBox(height: 8),
            ...current.map((c) => _ChargeCard(
                  charge: c,
                  expanded: _expanded.contains(c.id),
                  isDark: widget.isDark,
                  icons: widget.icons,
                  onToggle: () => setState(() {
                    _expanded.contains(c.id)
                        ? _expanded.remove(c.id)
                        : _expanded.add(c.id);
                  }),
                  onBulkDiscount: c.payments.isNotEmpty
                      ? () => widget.onBulkSheet(context, c)
                      : null,
                  onCancel: () => widget.onCancel(context, c.id),
                  onEditPayment: (p) => widget.onOpenSheet(context, c, p),
                )),
          ],
          if (finalized.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionTitle('✅ Finalizadas', widget.isDark),
            const SizedBox(height: 8),
            ...finalized.map((c) => _ChargeCard(
                  charge: c,
                  expanded: _expanded.contains(c.id),
                  isDark: widget.isDark,
                  icons: widget.icons,
                  finalized: true,
                  onToggle: () => setState(() {
                    _expanded.contains(c.id)
                        ? _expanded.remove(c.id)
                        : _expanded.add(c.id);
                  }),
                  onBulkDiscount: null,
                  onCancel: null,
                  onEditPayment: (p) => widget.onOpenSheet(context, c, p),
                )),
          ],
        ],
      ],
    );
  }
}

// ── User: suas cobranças ──────────────────────────────────────────────────────

class _UserExtraView extends StatelessWidget {
  final List<ExtraCharge> charges;
  final int year;
  final int month;
  final bool isDark;
  final void Function(int) onYearChanged;
  final void Function(int) onMonthChanged;
  final Future<void> Function(BuildContext, ExtraCharge, ExtraChargePayment)
      onOpenSheet;

  const _UserExtraView({
    required this.charges,
    required this.year,
    required this.month,
    required this.isDark,
    required this.onYearChanged,
    required this.onMonthChanged,
    required this.onOpenSheet,
  });

  @override
  Widget build(BuildContext context) {
    final filtered =
        charges.where((c) => c.year == year && c.month == month).toList();
    final pending = filtered.where((c) {
      if (c.isCancelled) return false;
      final p = c.payments.firstOrNull;
      return p == null || !p.isPaid;
    }).toList();
    final paid = filtered.where((c) {
      if (c.isCancelled) return false;
      final p = c.payments.firstOrNull;
      return p != null && p.isPaid;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          _YearPicker(year: year, isDark: isDark, onChanged: onYearChanged),
        ]),
        const SizedBox(height: 12),
        _MonthPicker(
          charges: charges,
          year: year,
          selected: month,
          isDark: isDark,
          isAdmin: false,
          onChanged: onMonthChanged,
        ),
        const SizedBox(height: 16),
        if (pending.isEmpty && paid.isEmpty)
          _EmptyState(
            icon: Icons.monetization_on_outlined,
            title: 'Nenhuma cobrança em ${_months[month - 1]}/$year',
            sub: '',
            isDark: isDark,
          )
        else ...[
          if (pending.isNotEmpty) ...[
            _SectionTitle('📌 Pendentes', isDark),
            const SizedBox(height: 8),
            ...pending.map((c) {
              final p = c.payments.firstOrNull;
              if (p == null) return const SizedBox.shrink();
              return _UserChargeCard(
                charge: c,
                payment: p,
                isDark: isDark,
                onTap: () => onOpenSheet(context, c, p),
              );
            }),
          ],
          if (paid.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionTitle('✅ Pagas', isDark),
            const SizedBox(height: 8),
            ...paid.map((c) {
              final p = c.payments.firstOrNull;
              if (p == null) return const SizedBox.shrink();
              return _UserChargeCard(
                charge: c,
                payment: p,
                isDark: isDark,
                paid: true,
                onTap: () => onOpenSheet(context, c, p),
              );
            }),
          ],
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS INTERNOS
// ══════════════════════════════════════════════════════════════════════════════

class _YearPicker extends StatelessWidget {
  final int year;
  final bool isDark;
  final void Function(int) onChanged;

  const _YearPicker({
    required this.year,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.slate800 : AppColors.slate100;
    final fg = isDark ? AppColors.slate400 : AppColors.slate600;
    final txt = isDark ? AppColors.slate100 : AppColors.slate800;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _ArrowBtn(
          icon: Icons.chevron_left,
          color: fg,
          onTap: () => onChanged(year - 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('$year',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: txt)),
        ),
        _ArrowBtn(
          icon: Icons.chevron_right,
          color: fg,
          onTap: () => onChanged(year + 1),
        ),
      ]),
    );
  }
}

class _ArrowBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ArrowBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox.square(
          dimension: 44,
          child: Icon(icon, size: 18, color: color),
        ),
      );
}

class _MonthPicker extends StatelessWidget {
  final List<ExtraCharge> charges;
  final int year;
  final int selected;
  final bool isDark;
  final bool isAdmin;
  final void Function(int) onChanged;

  const _MonthPicker({
    required this.charges,
    required this.year,
    required this.selected,
    required this.isDark,
    required this.isAdmin,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1.3,
      ),
      itemCount: 12,
      itemBuilder: (_, i) {
        final m = i + 1;
        final mc =
            charges.where((c) => c.year == year && c.month == m).toList();
        final active = mc.where((c) => !c.isCancelled).toList();

        final bool allPaid;
        final bool hasPending;
        if (isAdmin) {
          allPaid = active.isNotEmpty && active.every((c) => c.isFinalized);
          hasPending = active.any((c) => !c.isFinalized);
        } else {
          allPaid = active.isNotEmpty &&
              active.every((c) {
                final p = c.payments.firstOrNull;
                return p != null && p.isPaid;
              });
          hasPending = active.any((c) {
            final p = c.payments.firstOrNull;
            return p == null || !p.isPaid;
          });
        }

        final isSelected = m == selected;
        final hasAny = mc.isNotEmpty;

        Color dotColor = AppColors.transparent;
        if (hasAny) {
          if (allPaid)
            dotColor = AppColors.green400;
          else if (hasPending)
            dotColor = AppColors.rose400;
          else
            dotColor = AppColors.slate300;
        }

        return GestureDetector(
          onTap: () => onChanged(m),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? AppColors.onDark : AppColors.slate900)
                  : (isDark ? AppColors.slate800 : AppColors.slate100),
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? null
                  : Border.all(
                      color: isDark ? AppColors.slate700 : AppColors.slate200),
            ),
            child: Opacity(
              opacity: !hasAny && !isSelected ? 0.45 : 1.0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _months[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? (isDark ? AppColors.slate900 : AppColors.onDark)
                          : (isDark ? AppColors.slate200 : AppColors.slate700),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? dotColor.withValues(alpha: .8)
                          : dotColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Card de cobrança (admin) ──────────────────────────────────────────────────

class _ChargeCard extends StatelessWidget {
  final ExtraCharge charge;
  final bool expanded;
  final bool isDark;
  final bool finalized;
  final GroupIcons icons;
  final VoidCallback onToggle;
  final VoidCallback? onBulkDiscount;
  final VoidCallback? onCancel;
  final void Function(ExtraChargePayment) onEditPayment;

  const _ChargeCard({
    required this.charge,
    required this.expanded,
    required this.isDark,
    required this.icons,
    this.finalized = false,
    required this.onToggle,
    this.onBulkDiscount,
    this.onCancel,
    required this.onEditPayment,
  });

  @override
  Widget build(BuildContext context) {
    final paidCt = charge.payments.where((p) => p.isPaid).length;
    final pendCt = charge.payments.length - paidCt;
    final border = charge.isCancelled
        ? (isDark ? AppColors.slate700 : AppColors.slate200)
        : finalized
            ? AppColors.green200
            : (isDark ? AppColors.slate700 : AppColors.slate200);
    final bgColor = charge.isCancelled
        ? (isDark ? AppColors.slate900 : AppColors.onDark)
        : finalized
            ? AppColors.green50.withValues(alpha: .5)
            : (isDark ? AppColors.slate900 : AppColors.onDark);

    return Opacity(
      opacity: charge.isCancelled ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(children: [
          // Header
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(charge.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.onDark
                                    : AppColors.slate900,
                              )),
                          const SizedBox(width: 6),
                          if (charge.isCancelled)
                            _Badge('Cancelada',
                                bg: isDark
                                    ? AppColors.slate700
                                    : AppColors.slate100,
                                fg: isDark
                                    ? AppColors.slate400
                                    : AppColors.slate500),
                          if (finalized && !charge.isCancelled)
                            _Badge('Finalizada',
                                bg: AppColors.green100,
                                fg: AppColors.primaryPressed,
                                icon: Icons.check_circle_rounded),
                        ]),
                        const SizedBox(height: 2),
                        Row(children: [
                          Text('R\$ ${charge.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.slate400
                                      : AppColors.slate500)),
                          if (charge.dueDate != null) ...[
                            const SizedBox(width: 8),
                            Text('Venc. ${_fmtDate(charge.dueDate!)}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.slate400
                                        : AppColors.slate500)),
                          ],
                          const SizedBox(width: 8),
                          Text('$paidCt pago${paidCt != 1 ? 's' : ''}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primaryPressed,
                                  fontWeight: FontWeight.w600)),
                          if (pendCt > 0) ...[
                            const SizedBox(width: 6),
                            Text('$pendCt pendente${pendCt != 1 ? 's' : ''}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.rose500,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ]),
                      ]),
                ),
                // Actions
                if (onBulkDiscount != null)
                  _IconTextBtn(
                    icon: Icons.monetization_on_outlined,
                    label: 'Desc.',
                    isDark: isDark,
                    onTap: onBulkDiscount!,
                  ),
                if (onCancel != null)
                  GestureDetector(
                    onTap: onCancel,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.delete_outline,
                          size: 18,
                          color:
                              isDark ? AppColors.slate500 : AppColors.slate400),
                    ),
                  ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: isDark ? AppColors.slate500 : AppColors.slate400,
                ),
              ]),
            ),
          ),

          // Expandido: lista de jogadores
          if (expanded) ...[
            Divider(
                height: 1,
                color: isDark ? AppColors.slate800 : AppColors.slate100),
            if (charge.payments.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Nenhum jogador atribuído.',
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark ? AppColors.slate400 : AppColors.slate500)),
              )
            else
              ...charge.payments.map((p) => _PaymentRow(
                    payment: p,
                    isDark: isDark,
                    icons: icons,
                    isCancelled: charge.isCancelled,
                    onEdit: () => onEditPayment(p),
                  )),
          ],
        ]),
      ),
    );
  }

  String _fmtDate(String s) {
    try {
      final d = AppDateUtils.parseOrNow(s);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return s;
    }
  }
}

class _PaymentRow extends StatelessWidget {
  final ExtraChargePayment payment;
  final bool isDark;
  final bool isCancelled;
  final GroupIcons icons;
  final VoidCallback onEdit;

  const _PaymentRow({
    required this.payment,
    required this.isDark,
    required this.isCancelled,
    required this.icons,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final paid = payment.isPaid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: isDark ? AppColors.slate800 : AppColors.slate50)),
      ),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PlayerNameWithIcon(
              name: payment.playerName,
              icons: icons,
              isGoalkeeper: payment.isGoalkeeper,
              iconSize: 11,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.slate100 : AppColors.slate800,
              ),
            ),
            const SizedBox(height: 2),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: [
                Text('R\$ ${payment.finalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 11,
                        color:
                            isDark ? AppColors.slate400 : AppColors.slate500)),
                if (payment.discount > 0)
                  Text('(desc. R\$ ${payment.discount.toStringAsFixed(2)})',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.primaryPressed)),
                if (payment.paidAt != null)
                  Text('· ${_fmtDate(payment.paidAt!)}',
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.slate400
                              : AppColors.slate500)),
              ],
            ),
          ]),
        ),
        _StatusBadge(paid: paid),
        if (!isCancelled) ...[
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onEdit,
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                  color: isDark ? AppColors.slate700 : AppColors.slate200),
              foregroundColor: isDark ? AppColors.slate300 : AppColors.slate600,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              textStyle:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Editar'),
          ),
        ],
      ]),
    );
  }

  String _fmtDate(String s) {
    try {
      final d = AppDateUtils.parseOrNow(s);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return s;
    }
  }
}

// ── Card de cobrança para user ────────────────────────────────────────────────

class _UserChargeCard extends StatelessWidget {
  final ExtraCharge charge;
  final ExtraChargePayment payment;
  final bool isDark;
  final bool paid;
  final VoidCallback onTap;

  const _UserChargeCard({
    required this.charge,
    required this.payment,
    required this.isDark,
    this.paid = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: paid
            ? AppColors.green50.withValues(alpha: .5)
            : (isDark ? AppColors.slate900 : AppColors.onDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: paid
              ? AppColors.green100
              : (isDark ? AppColors.slate700 : AppColors.slate200),
        ),
      ),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(charge.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.onDark : AppColors.slate800,
                )),
            const SizedBox(height: 4),
            Row(children: [
              Text('R\$ ${payment.finalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.slate400 : AppColors.slate500)),
              if (payment.discount > 0) ...[
                const SizedBox(width: 8),
                Text('Desconto: R\$ ${payment.discount.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.primaryPressed)),
              ],
              if (charge.dueDate != null) ...[
                const SizedBox(width: 8),
                Text('Venc. ${_fmtDate(charge.dueDate!)}',
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark ? AppColors.slate400 : AppColors.slate500)),
              ],
              if (payment.paidAt != null) ...[
                const SizedBox(width: 8),
                Text('Pago em ${_fmtDate(payment.paidAt!)}',
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark ? AppColors.slate400 : AppColors.slate500)),
              ],
            ]),
          ]),
        ),
        _StatusBadge(paid: paid),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            side: BorderSide(
                color: isDark ? AppColors.slate700 : AppColors.slate200),
            foregroundColor: isDark ? AppColors.slate300 : AppColors.slate600,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            textStyle:
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(paid ? 'Ver' : 'Pagar'),
        ),
      ]),
    );
  }

  String _fmtDate(String s) {
    try {
      final d = AppDateUtils.parseOrNow(s);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return s;
    }
  }
}

// ── Helpers de UI ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  final bool isDark;
  const _SectionTitle(this.text, this.isDark);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.slate300 : AppColors.slate700,
        ),
      );
}

class _Badge extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;
  const _Badge(this.text, {required this.bg, required this.fg, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: fg),
            const SizedBox(width: 2),
          ],
          Text(text,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
        ]),
      );
}

class _StatusBadge extends StatelessWidget {
  final bool paid;
  const _StatusBadge({required this.paid});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: paid ? AppColors.green100 : AppColors.rose50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            paid ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 12,
            color: paid ? AppColors.primaryPressed : AppColors.rose500,
          ),
          const SizedBox(width: 4),
          Text(
            paid ? 'Pago' : 'Pendente',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: paid ? AppColors.primaryPressed : AppColors.rose500,
            ),
          ),
        ]),
      );
}

class _IconTextBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _IconTextBtn({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(
                color: isDark ? AppColors.slate700 : AppColors.slate200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 12,
                color: isDark ? AppColors.slate400 : AppColors.slate600),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.slate400 : AppColors.slate600,
                )),
          ]),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final bool isDark;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.sub,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(children: [
            Icon(icon,
                size: 40,
                color: isDark ? AppColors.slate600 : AppColors.slate300),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.slate400 : AppColors.slate500,
                )),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(sub,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark ? AppColors.slate500 : AppColors.slate400)),
              ),
            ],
          ]),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String error;
  final bool isDark;
  const _ErrorState(this.error, {required this.isDark});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Erro: $error',
            style: const TextStyle(color: AppColors.rose500, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
}

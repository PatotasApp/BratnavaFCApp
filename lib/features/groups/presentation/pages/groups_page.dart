import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_constants.dart';
import '../../../../core/api/api_response.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../group_settings/presentation/providers/group_settings_provider.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/app_page_header.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../../../shared/presentation/widgets/prototype_ui.dart';
import '../../../../shared/presentation/widgets/user_profile_link.dart';

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ─────────────────────────────────────────────────────────────────────────────
// DTOs
// ─────────────────────────────────────────────────────────────────────────────

class _PlayerDto {
  final String id;
  final String? userId;
  final String? userName;
  final String? photoUrl;
  final String name;
  final int skillPoints;
  final bool isGoalkeeper;
  final bool isGuest;
  final int status;
  final int? guestStarRating;
  // mensalista ratings
  final int? attackRating;
  final int? defenseRating;
  final int? overallRating; // displayed as "Físico"

  const _PlayerDto({
    required this.id,
    this.userId,
    this.userName,
    this.photoUrl,
    required this.name,
    required this.skillPoints,
    required this.isGoalkeeper,
    required this.isGuest,
    required this.status,
    this.guestStarRating,
    this.attackRating,
    this.defenseRating,
    this.overallRating,
  });

  /// Computed overall: average of the three ratings, or null if none set.
  double? get computedOverall {
    final a = attackRating;
    final d = defenseRating;
    final o = overallRating;
    if (a == null && d == null && o == null) return null;
    final vals = [if (a != null) a, if (d != null) d, if (o != null) o];
    return vals.reduce((x, y) => x + y) / vals.length;
  }

  factory _PlayerDto.fromJson(Map<String, dynamic> j) => _PlayerDto(
        id: j['id'] as String? ?? '',
        userId: j['userId'] as String?,
        userName: j['userName'] as String?,
        photoUrl: j['photoUrl'] as String?,
        name: j['name'] as String? ?? '',
        skillPoints: j['skillPoints'] as int? ?? 0,
        isGoalkeeper: j['isGoalkeeper'] as bool? ?? false,
        isGuest: j['isGuest'] as bool? ?? false,
        status: j['status'] as int? ?? 1,
        guestStarRating: j['guestStarRating'] as int?,
        attackRating: j['attackRating'] as int?,
        defenseRating: j['defenseRating'] as int?,
        overallRating: j['overallRating'] as int?,
      );
}

/// GUIDs chegam com caixa e chaves diferentes conforme o endpoint que os
/// devolve, então comparar as strings cruas faz o papel sumir sem aviso.
String _normId(String? id) =>
    (id ?? '').trim().toLowerCase().replaceAll(RegExp(r'[{}]'), '');

class _GroupDto {
  final String id;
  final String name;
  final String? logoUrl;
  final List<String> adminIds;

  /// Vem no mesmo payload que `adminIds` — é assim que o site monta a lista de
  /// financeiros da patota. Eu tinha buscado isso num GET
  /// `/api/Groups/{id}/financeiros` que não existe: aquela rota só aceita POST
  /// e DELETE, então a chamada falhava calada e ninguém nunca ganhava o selo.
  final List<String> financeiroIds;

  final List<_PlayerDto> players;
  final String createdByUserId;

  const _GroupDto({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.adminIds,
    required this.financeiroIds,
    required this.players,
    required this.createdByUserId,
  });

  factory _GroupDto.fromJson(Map<String, dynamic> j) => _GroupDto(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        logoUrl: j['logoUrl'] as String?,
        adminIds: List<String>.from(j['adminIds'] as List? ?? const []),
        financeiroIds:
            List<String>.from(j['financeiroIds'] as List? ?? const []),
        players: ((j['players'] as List?) ?? const [])
            .map((e) => _PlayerDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdByUserId: j['createdByUserId'] as String? ?? '',
      );
}

class _MyPlayerItem {
  final String playerId;
  final String? userId;
  final String groupId;
  final String playerName;
  final bool isGoalkeeper;
  final int skillPoints;
  final int status;
  final String groupName;
  final bool isGuest;

  const _MyPlayerItem({
    required this.playerId,
    this.userId,
    required this.groupId,
    required this.playerName,
    required this.isGoalkeeper,
    required this.skillPoints,
    required this.status,
    required this.groupName,
    required this.isGuest,
  });

  factory _MyPlayerItem.fromJson(Map<String, dynamic> j) => _MyPlayerItem(
        playerId: j['playerId'] as String? ?? '',
        userId: j['userId'] as String?,
        groupId: j['groupId'] as String? ?? '',
        playerName: j['playerName'] as String? ?? '',
        isGoalkeeper: j['isGoalkeeper'] as bool? ?? false,
        skillPoints: j['skillPoints'] as int? ?? 0,
        status: j['status'] as int? ?? 1,
        groupName: j['groupName'] as String? ?? '',
        isGuest: j['isGuest'] as bool? ?? false,
      );
}

class _UserResult {
  final String id;
  final String userName;
  final String firstName;
  final String lastName;
  final String email;

  const _UserResult({
    required this.id,
    required this.userName,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  factory _UserResult.fromJson(Map<String, dynamic> j) => _UserResult(
        id: j['id'] as String? ?? '',
        userName: j['userName'] as String? ?? '',
        firstName: j['firstName'] as String? ?? '',
        lastName: j['lastName'] as String? ?? '',
        email: j['email'] as String? ?? '',
      );

  String get fullName => '$firstName $lastName'.trim();
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final _dioProv = Provider<Dio>((ref) => ref.watch(dioProvider));

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class GroupsPage extends ConsumerStatefulWidget {
  const GroupsPage({super.key});

  @override
  ConsumerState<GroupsPage> createState() => _GroupsPageState();
}

// payment badge record
typedef _PaymentBadge = ({int pendingMonths, int pendingExtras});

class _GroupsPageState extends ConsumerState<GroupsPage> {
  List<_MyPlayerItem> _myPlayers = [];
  bool _mineLoading = true;

  String? _expandedGroupId;
  _GroupDto? _group;
  bool _groupLoading = false;
  String? _groupError;

  // playerId → pending counts (only populated for financeiros)
  Map<String, _PaymentBadge> _paymentMap = {};

  // grupos onde o usuário é admin mas ainda não tem jogador (ex: recém-criado)
  List<Map<String, String>> _adminOnlyGroups = [];

  Dio get _dio => ref.read(_dioProv);

  static dynamic _unwrap(dynamic data) {
    if (data is Map && data.containsKey('data')) return data['data'];
    if (data is Map && data.containsKey('Data')) return data['Data'];
    return data;
  }

  List<Map<String, String>> get _myGroups {
    final activeGroupId =
        ref.read(accountStoreProvider).activeAccount?.activeGroupId;
    final seen = <String>{};
    final result = <Map<String, String>>[];
    for (final p in _myPlayers) {
      if (seen.add(p.groupId)) {
        result.add({
          'groupId': p.groupId,
          'groupName': p.groupName,
        });
      }
    }
    for (final g in _adminOnlyGroups) {
      if (seen.add(g['groupId']!)) {
        result.add(g);
      }
    }
    // Mostra apenas a patota ativa (selecionada na topbar)
    if (activeGroupId == null) return result;
    return result.where((g) => g['groupId'] == activeGroupId).toList();
  }

  _MyPlayerItem? get _myPlayerInExpanded => _expandedGroupId == null
      ? null
      : _myPlayers.where((p) => p.groupId == _expandedGroupId).firstOrNull;

  String get _activePlayerId => _myPlayerInExpanded?.playerId ?? '';

  bool _isGroupAdmin(String groupId) {
    final account = ref.read(accountStoreProvider).activeAccount;
    if (account == null) return false;

    // Depois que o detalhe da patota carregou, a lista de vínculos do próprio
    // grupo é a fonte autoritativa. Isso também impede que um papel de
    // plataforma (ou um cache do grupo anterior) libere edição nesta tela.
    final group = _group;
    if (group != null && _sameId(group.id, groupId)) {
      return group.adminIds.any((id) => _sameId(id, account.userId));
    }
    return account.isGroupAdmin(groupId);
  }

  bool _canSeePaymentStatus(String groupId) {
    final account = ref.read(accountStoreProvider).activeAccount;
    if (account == null) return false;

    // Exclusivo do financeiro da patota. Pendência de pagamento é dado sensível
    // e quem cuida disso é o financeiro — administrar a patota (marcar partida,
    // montar time, editar jogador) não dá acesso a quem está devendo.
    // Admin global também não entra: o papel é operacional, não financeiro.
    // O payload da patota traz a lista autoritativa de financeiros. Quando ele
    // já está disponível, inclusive uma resposta negativa deve prevalecer
    // sobre flags antigos ou papéis de plataforma.
    final group = _group;
    if (group != null && _sameId(group.id, groupId)) {
      return group.financeiroIds.any((id) => _sameId(id, account.userId));
    }
    return account.isGroupFinanceiro(groupId);
  }

  static bool _sameId(String a, String b) {
    final na = _normId(a);
    return na.isNotEmpty && na == _normId(b);
  }

  Future<void> _loadPaymentData(String groupId) async {
    // Quem não é financeiro nem chega a baixar os dados — evita trafegar a grade
    // de pagamentos da patota inteira para quem não pode vê-la.
    if (!_canSeePaymentStatus(groupId)) {
      if (mounted) setState(() => _paymentMap = {});
      return;
    }

    final year = DateTime.now().year;
    final currentMonth = DateTime.now().month;

    try {
      final results = await Future.wait([
        _dio.get(ApiConstants.monthlyGrid(groupId, year)),
        // Sem paginação explícita o backend devolve só a primeira página no
        // tamanho padrão, e cobranças ficam de fora da contagem. O site pede
        // 100 de uma vez; seguimos igual.
        _dio.get(
          ApiConstants.extraCharges(groupId),
          queryParameters: {'year': year, 'page': 1, 'pageSize': 100},
        ),
      ]);

      final gridRaw = _unwrap(results[0].data);
      // `extra-charges` responde um PagedResult (`{page, pageSize, total,
      // items}`), não uma lista. O `as List?` que estava aqui não devolvia
      // null nesse caso: estourava, e o catch lá embaixo zerava o mapa
      // inteiro — por isso nem "Em dia" aparecia, apesar da grade mensal ter
      // vindo certa. `unwrapList` já sabe desembrulhar as duas formas.
      final extrasRaw = unwrapList(results[1].data);
      final grid =
          gridRaw is Map<String, dynamic> ? gridRaw : <String, dynamic>{};

      final hasMonthlyFee = (grid['monthlyFee'] as num? ?? 0) > 0;
      final map = <String, _PaymentBadge>{};

      // ── monthly grid rows ──
      for (final row in (grid['players'] as List? ?? [])) {
        final r = row as Map<String, dynamic>;
        final playerId = r['playerId'] as String? ?? '';
        final joinedYear = r['joinedYear'] as int? ?? 0;
        final joinedMonth = r['joinedMonth'] as int? ?? 1;

        int pendingMonths = 0;
        if (hasMonthlyFee) {
          for (final m in (r['months'] as List? ?? [])) {
            final month = m as Map<String, dynamic>;
            final mn = month['month'] as int? ?? 0;
            if (mn > currentMonth) continue;
            if (joinedYear == year && mn < joinedMonth) continue;
            if ((month['status'] as int? ?? 0) == 0) pendingMonths++;
          }
        }
        map[playerId] = (pendingMonths: pendingMonths, pendingExtras: 0);
      }

      // ── extra charges ──
      for (final charge in extrasRaw) {
        final c = charge as Map<String, dynamic>;
        if (c['isCancelled'] == true) continue;
        for (final payment in (c['payments'] as List? ?? [])) {
          final p = payment as Map<String, dynamic>;
          if ((p['status'] as int? ?? -1) != 0) continue;
          final pid = p['playerId'] as String? ?? '';
          final existing = map[pid];
          if (existing != null) {
            map[pid] = (
              pendingMonths: existing.pendingMonths,
              pendingExtras: existing.pendingExtras + 1
            );
          } else {
            map[pid] = (pendingMonths: 0, pendingExtras: 1);
          }
        }
      }

      if (mounted) setState(() => _paymentMap = map);
    } catch (_) {
      // Silencioso, e sem zerar: uma falha de rede não deve apagar badges que
      // já estavam corretos na tela. Se nunca carregou, o mapa já está vazio.
    }
  }

  List<_PlayerDto> get _activePlayers =>
      _group?.players.where((p) => p.status == 1 && !p.isGuest).toList() ?? [];

  List<_PlayerDto> get _guestPlayers =>
      _group?.players.where((p) => p.status == 1 && p.isGuest).toList() ?? [];

  List<_PlayerDto> get _inactivePlayers {
    final account = ref.read(accountStoreProvider).activeAccount;
    if (account == null) return [];
    final isAdminHere =
        _expandedGroupId != null && account.isGroupAdmin(_expandedGroupId!);
    if (!isAdminHere) return [];
    return _group?.players.where((p) => p.status != 1).toList() ?? [];
  }

  List<_PlayerDto> get _sortedActivePlayers {
    final sorted = List<_PlayerDto>.from(_activePlayers);
    sorted.sort((a, b) {
      if (a.id == _activePlayerId) return -1;
      if (b.id == _activePlayerId) return 1;
      return 0;
    });
    return sorted;
  }

  Set<String> get _existingUserIds => (_group?.players ?? [])
      .where((p) => !p.isGuest && p.userId != null)
      .map((p) => p.userId!)
      .toSet();

  @override
  void initState() {
    super.initState();
    _loadMine().then((_) {
      _loadAdminGroups();
      if (_myGroups.length == 1) {
        _openGroup(_myGroups.first['groupId']!);
      }
    });
  }

  Future<void> _loadMine() async {
    setState(() => _mineLoading = true);
    try {
      final res = await _dio.get(ApiConstants.playersMe);
      setState(() {
        // `unwrapList` em vez de `as List?`: o cast estoura se a rota passar a
        // paginar, e o erro só apareceria como tela vazia.
        _myPlayers = unwrapList(res.data)
            .map((e) => _MyPlayerItem.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (_) {
      setState(() => _myPlayers = []);
    } finally {
      if (mounted) setState(() => _mineLoading = false);
    }
  }

  Future<void> _loadAdminGroups() async {
    final account = ref.read(accountStoreProvider).activeAccount;
    if (account == null) return;
    try {
      final res = await _dio.get(ApiConstants.groupsByAdmin(account.userId));
      final playerGroupIds = _myPlayers.map((p) => p.groupId).toSet();
      if (mounted) {
        setState(() {
          _adminOnlyGroups = unwrapList(res.data)
              .map((e) => e as Map<String, dynamic>)
              .where((g) => !playerGroupIds.contains(g['id'] as String? ?? ''))
              .map((g) => {
                    'groupId': g['id'] as String? ?? '',
                    'groupName': g['name'] as String? ?? '',
                  })
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _openGroup(String groupId) async {
    setState(() {
      _expandedGroupId = groupId;
      _groupLoading = true;
      _groupError = null;
      _group = null;
      _paymentMap = {};
    });

    try {
      final res = await _dio.get(ApiConstants.groupById(groupId));
      final raw = _unwrap(res.data);
      setState(() => _group = _GroupDto.fromJson(raw as Map<String, dynamic>));
      // Os papéis já vieram no payload acima. Só os badges de pagamento ainda
      // precisam de uma segunda chamada, que roda sem bloquear a tela.
      _loadPaymentData(groupId);
    } catch (e) {
      setState(() {
        _groupError =
            extractDioError(e, 'Não foi possível carregar os dados da patota.');
      });
    } finally {
      if (mounted) setState(() => _groupLoading = false);
    }
  }

  /// Papel de cada usuário na patota. Financeiro tem precedência sobre admin
  /// porque é o papel mais específico — quem acumula os dois aparece como
  /// Financeiro, igual ao protótipo (Maria é "Financeiro", não "Admin").
  /// Chaveado por userId normalizado — ver [_normId].
  Map<String, List<String>> _roleLabels() {
    final labels = <String, List<String>>{};
    for (final id in _group?.adminIds ?? const <String>[]) {
      final key = _normId(id);
      if (key.isNotEmpty) (labels[key] ??= <String>[]).add('Admin');
    }
    for (final id in _group?.financeiroIds ?? const <String>[]) {
      final key = _normId(id);
      if (key.isNotEmpty) (labels[key] ??= <String>[]).add('Financeiro');
    }
    return labels;
  }

  void _toggleGroup(String groupId) {
    if (_expandedGroupId == groupId) {
      setState(() {
        _expandedGroupId = null;
        _group = null;
        _groupError = null;
        _paymentMap = {};
      });
      return;
    }
    _openGroup(groupId);
  }

  void _reloadGroup() {
    final id = _expandedGroupId;
    if (id != null) {
      _openGroup(id);
    }
  }

  Future<void> _handleLeave() async {
    if (_activePlayerId.isEmpty) return;
    try {
      await _dio.post(ApiConstants.playerLeaveGroup(_activePlayerId));
      await _loadMine();
      _reloadGroup();
    } catch (_) {}
  }

  void _showCreateGroup() {
    final account = ref.read(accountStoreProvider).activeAccount;
    if (account == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => _CreateGroupSheet(
        onSubmit: (name) async {
          await _dio.post(ApiConstants.groups, data: {
            'name': name,
            'userAdminIds': [account.userId],
            'scheduleMatchDate': null,
            'createdByUserId': account.userId,
          });

          await _loadMine();
          await _loadAdminGroups();
          await ref
              .read(authNotifierProvider.notifier)
              .refreshGroupMembership();
          ref.invalidate(myPlayersProvider);
          // Abre automaticamente se agora há exatamente uma patota
          if (_myGroups.length == 1) {
            _openGroup(_myGroups.first['groupId']!);
          }
        },
      ),
    );
  }

  /// Cria um convidado — jogador sem conta no sistema.
  ///
  /// Extraído da folha para poder ser chamado também de dentro da folha de
  /// convite, que agora oferece "Usuário" e "Convidado" no mesmo lugar.
  Future<void> _createGuest(
      String groupId, String name, bool isGoalkeeper, int? starRating) async {
    await _dio.post(
      ApiConstants.playersCreate,
      data: {
        'name': name,
        'groupId': groupId,
        'skillPoints': 0,
        'isGoalkeeper': isGoalkeeper,
        'isGuest': true,
        'status': 1,
        if (starRating != null) 'guestStarRating': starRating,
      },
    );
    _reloadGroup();
  }

  void _showAddGuest(String groupId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => _AddGuestSheet(
        onSubmit: (name, isGoalkeeper, starRating) =>
            _createGuest(groupId, name, isGoalkeeper, starRating),
      ),
    );
  }

  void _showInvite(String groupId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => _InviteSheet(
        dio: _dio,
        groupId: groupId,
        existingUserIds: _existingUserIds,
        guestPlayers: _guestPlayers,
        onInvited: () async => _reloadGroup(),
        onAddGuest: (name, isGoalkeeper, starRating) =>
            _createGuest(groupId, name, isGoalkeeper, starRating),
      ),
    );
  }

  /// Abre o editor na seção correspondente à aba de origem.
  ///
  /// As duas abas levavam à mesma folha completa, o que fazia a lista de
  /// avaliações abrir campos de cadastro e vice-versa — o contexto de onde se
  /// clicou já diz o que a pessoa quer mexer.
  void _showEditPlayer(_PlayerDto player,
      {_EditSection section = _EditSection.player}) {
    final isAdminHere =
        _expandedGroupId != null ? _isGroupAdmin(_expandedGroupId!) : false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => _EditPlayerSheet(
        player: player,
        isAdmin: isAdminHere,
        section: section,
        onSaved: (dto) async {
          await _dio.put(ApiConstants.playerOps(player.id), data: dto);
          _reloadGroup();
        },
        // Remove available for admins on non-guest players with a linked account
        onRemove: (isAdminHere && !player.isGuest && player.userId != null)
            ? () async {
                await _dio.post(ApiConstants.playerRemoveFromGroup(player.id));
                _reloadGroup();
              }
            : null,
      ),
    );
  }

  void _showLeaveConfirm() {
    showDialog<void>(
      context: context,
      builder: (_) => _LeaveConfirmDialog(onConfirm: _handleLeave),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Garante rebuild quando a patota ativa ou suas permissões mudam.
    final account = ref.watch(accountStoreProvider).activeAccount;
    final activeGroupId = account?.activeGroupId ?? _expandedGroupId;
    final canConfigure = activeGroupId != null &&
        activeGroupId.isNotEmpty &&
        _isGroupAdmin(activeGroupId);
    final activeGroupName = _group?.name ??
        (_myGroups.isNotEmpty ? _myGroups.first['groupName'] : null);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _GroupsHeader(
            groupName: activeGroupName,
            logoUrl: _group?.logoUrl,
            onSettings: canConfigure && _myGroups.isNotEmpty
                ? () => context.push('/app/settings')
                : null,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_mineLoading)
                    _buildLoadingHeader()
                  else if (_myGroups.isEmpty)
                    _buildEmptyHeader(isDark)
                  else if (_myGroups.length == 1)
                    _buildSingleGroup(isDark)
                  else
                    _buildAccordion(isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingHeader() {
    return const _GradientCard(
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.onDark70),
          ),
          SizedBox(width: 12),
          Text(
            'Carregando patotas...',
            style: TextStyle(fontSize: 14, color: AppColors.onDark70),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHeader(bool isDark) {
    return _GradientCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.group_outlined, size: 36, color: AppColors.onDark38),
          const SizedBox(height: 12),
          const Text(
            'Você não faz parte de nenhuma patota.',
            style: TextStyle(fontSize: 14, color: AppColors.onDark60),
          ),
          const SizedBox(height: 16),
          _DarkBtn(
            label: 'Criar patota',
            icon: Icons.add,
            style: _DarkBtnStyle.solid,
            onTap: _showCreateGroup,
          ),
        ],
      ),
    );
  }

  Widget _buildSingleGroup(bool isDark) {
    final g = _myGroups.first;
    final groupId = g['groupId']!;
    final groupName = _group?.name ?? g['groupName']!;
    final isAdminHere = _isGroupAdmin(groupId);
    final account = ref.watch(accountStoreProvider).activeAccount;
    final isCreator = _group?.createdByUserId == account?.userId;
    final icons =
        GroupIcons.from(ref.watch(groupSettingsProvider(groupId)).valueOrNull);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GradientCard(
          dotPattern: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Protótipo: eyebrow "PATOTA ATIVA", nome grande e o avatar do
              // grupo à DIREITA. Antes o avatar vinha à esquerda e faltava o
              // rótulo, então a faixa não se lia como "esta é a patota ativa".
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PATOTA ATIVA',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .77,
                            color: AppColors.primaryHover,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          groupName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.onDark,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _groupLoading
                              ? 'Carregando...'
                              : _group != null
                                  ? '${_activePlayers.length} mensalista${_activePlayers.length != 1 ? 's' : ''} · ${_guestPlayers.length} convidado${_guestPlayers.length != 1 ? 's' : ''}'
                                  : '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.darkTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_groupLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onDark70,
                      ),
                    )
                  else if (_group?.logoUrl?.trim().isNotEmpty == true)
                    AvatarWidget(
                      name: groupName,
                      photoUrl: _group!.logoUrl,
                      size: 50,
                      fit: BoxFit.cover,
                      borderRadius: 16,
                    )
                  else
                    _GroupAvatar(
                      letter:
                          groupName.isEmpty ? 'G' : groupName.characters.first,
                      size: 50,
                      radius: 16,
                    ),
                ],
              ),
              if (!_groupLoading && _group != null) ...[
                const SizedBox(height: 16),
                _HeaderButtons(
                  isAdminHere: isAdminHere,
                  isCreator: isCreator,
                  myPlayer: _myPlayerInExpanded,
                  activePlayerId: _activePlayerId,
                  onAddGuest: () => _showAddGuest(groupId),
                  onInvite: () => _showInvite(groupId),
                  onCreateGroup: _showCreateGroup,
                  onLeave: _showLeaveConfirm,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.onDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppColors.onDark.withValues(alpha: 0.08)
                  : AppColors.darkApp.withValues(alpha: 0.07),
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: AppColors.darkApp.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          padding: const EdgeInsets.all(20),
          child: _GroupContent(
            group: _group,
            groupLoading: _groupLoading,
            groupError: _groupError,
            activePlayers: _sortedActivePlayers,
            guestPlayers: _guestPlayers,
            inactivePlayers: _inactivePlayers,
            activePlayerId: _activePlayerId,
            isAdminHere: isAdminHere,
            isFinanceiroHere: _expandedGroupId != null
                ? _canSeePaymentStatus(_expandedGroupId!)
                : false,
            paymentMap: _paymentMap,
            icons: icons,
            isDark: isDark,
            onEditPlayer: _showEditPlayer,
            onEditRatings: (p) =>
                _showEditPlayer(p, section: _EditSection.ratings),
            roleLabels: _roleLabels(),
          ),
        ),
      ],
    );
  }

  Widget _buildAccordion(bool isDark) {
    final account = ref.watch(accountStoreProvider).activeAccount;
    final expandedIcons = _expandedGroupId != null
        ? GroupIcons.from(
            ref.watch(groupSettingsProvider(_expandedGroupId!)).valueOrNull)
        : GroupIcons.defaults;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GradientCard(
          dotPattern: true,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.onDark.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.onDark.withValues(alpha: 0.2)),
                ),
                child: const Icon(
                  Icons.group_outlined,
                  size: 22,
                  color: AppColors.onDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Minha patota',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.onDark,
                      ),
                    ),
                    Text(
                      '${_myGroups.length} patotas',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.onDark60),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ..._myGroups.map((g) {
          final groupId = g['groupId']!;
          final groupName = g['groupName']!;
          final isExpanded = _expandedGroupId == groupId;
          final isAdminHere = _isGroupAdmin(groupId);
          final myPlayer =
              _myPlayers.where((p) => p.groupId == groupId).firstOrNull;
          final isCreator =
              isExpanded && _group?.createdByUserId == account?.userId;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AccordionItem(
              groupName: groupName,
              isExpanded: isExpanded,
              isAdminHere: isAdminHere,
              isCreator: isCreator,
              myPlayer: myPlayer,
              isDark: isDark,
              onToggle: () => _toggleGroup(groupId),
              onAddGuest: () => _showAddGuest(groupId),
              onInvite: () => _showInvite(groupId),
              onLeave: _showLeaveConfirm,
              groupContent: isExpanded
                  ? _GroupContent(
                      group: _group,
                      groupLoading: _groupLoading,
                      groupError: _groupError,
                      activePlayers: _sortedActivePlayers,
                      guestPlayers: _guestPlayers,
                      inactivePlayers: _inactivePlayers,
                      activePlayerId: _activePlayerId,
                      isAdminHere: isAdminHere,
                      isFinanceiroHere: _canSeePaymentStatus(groupId),
                      paymentMap: _paymentMap,
                      icons: expandedIcons,
                      isDark: isDark,
                      onEditPlayer: _showEditPlayer,
                      onEditRatings: (p) =>
                          _showEditPlayer(p, section: _EditSection.ratings),
                      roleLabels: _roleLabels(),
                    )
                  : null,
            ),
          );
        }),
      ],
    );
  }
}

class _GroupsHeader extends StatelessWidget {
  final String? groupName;
  final String? logoUrl;
  final VoidCallback? onSettings;

  const _GroupsHeader({
    required this.groupName,
    required this.logoUrl,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return AppPageHeader.main(
      title: 'Minha patota',
      subtitle: groupName?.isNotEmpty == true
          ? groupName!
          : 'Organize seus jogadores',
      icon: Icons.groups_outlined,
      iconWidget: AvatarWidget(
        name: groupName ?? 'Patota',
        photoUrl: logoUrl,
        size: 42,
        borderRadius: 13,
      ),
      actions: onSettings == null
          ? const []
          : [
              AppPageHeaderAction(
                onPressed: onSettings,
                tooltip: 'Configurações da patota',
                icon: Icons.settings_outlined,
              ),
            ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header Buttons
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderButtons extends StatelessWidget {
  final bool isAdminHere;
  final bool isCreator;
  final _MyPlayerItem? myPlayer;
  final String activePlayerId;
  final VoidCallback onAddGuest;
  final VoidCallback onInvite;
  final VoidCallback onCreateGroup;
  final VoidCallback onLeave;

  const _HeaderButtons({
    required this.isAdminHere,
    required this.isCreator,
    required this.myPlayer,
    required this.activePlayerId,
    required this.onAddGuest,
    required this.onInvite,
    required this.onCreateGroup,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final showLeave = !isAdminHere &&
        activePlayerId.isNotEmpty &&
        myPlayer != null &&
        !myPlayer!.isGuest;
    final showCreatorLeave = isAdminHere && isCreator;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Um botão "Convidar" só — a folha de convite já decide entre usuário
        // e convidado. Antes eram dois botões separados.
        //
        // Restrito a admin, de propósito. O protótipo mostra este botão para
        // todo mundo, mas lá não existem papéis: é mock. Trazer gente para a
        // patota é decisão de admin, então esta divergência com o protótipo é
        // intencional e não deve ser "corrigida".
        if (isAdminHere)
          _DarkBtn(
            label: 'Convidar',
            icon: Icons.person_add_alt_1_outlined,
            style: _DarkBtnStyle.solid,
            onTap: onInvite,
          ),
        // No protótipo "Convidar" e "Nova patota" têm o mesmo peso visual:
        // fundo claro sobre o card escuro. O `ghost` deixava este quase
        // invisível — só um contorno translúcido sobre fundo escuro.
        _DarkBtn(
          label: 'Nova patota',
          icon: Icons.add,
          style: _DarkBtnStyle.solid,
          onTap: onCreateGroup,
        ),
        if (showLeave || showCreatorLeave)
          _DarkBtn(
            label: 'Sair',
            icon: Icons.logout,
            style: _DarkBtnStyle.danger,
            onTap: onLeave,
          ),
      ],
    );
  }
}

enum _DarkBtnStyle { ghost, solid, danger }

class _DarkBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final _DarkBtnStyle style;
  final VoidCallback onTap;

  const _DarkBtn({
    required this.label,
    required this.icon,
    required this.style,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color borderColor;
    late final Color textColor;

    switch (style) {
      case _DarkBtnStyle.ghost:
        bg = AppColors.onDark.withValues(alpha: 0.10);
        borderColor = AppColors.onDark.withValues(alpha: 0.20);
        textColor = AppColors.onDark;
        break;
      case _DarkBtnStyle.solid:
        bg = AppColors.onDark;
        borderColor = AppColors.transparent;
        textColor = AppColors.lightText;
        break;
      case _DarkBtnStyle.danger:
        bg = AppColors.prototypeDanger.withValues(alpha: 0.20);
        borderColor = AppColors.prototypeDanger.withValues(alpha: 0.35);
        textColor = AppColors.rose200;
        break;
    }

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: textColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Accordion
// ─────────────────────────────────────────────────────────────────────────────

class _AccordionItem extends StatelessWidget {
  final String groupName;
  final bool isExpanded;
  final bool isAdminHere;
  final bool isCreator;
  final _MyPlayerItem? myPlayer;
  final bool isDark;
  final VoidCallback onToggle;
  final VoidCallback onAddGuest;
  final VoidCallback onInvite;
  final VoidCallback onLeave;
  final Widget? groupContent;

  const _AccordionItem({
    required this.groupName,
    required this.isExpanded,
    required this.isAdminHere,
    required this.isCreator,
    required this.myPlayer,
    required this.isDark,
    required this.onToggle,
    required this.onAddGuest,
    required this.onInvite,
    required this.onLeave,
    this.groupContent,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? AppColors.onDark.withValues(alpha: 0.08)
        : AppColors.darkApp.withValues(alpha: 0.06);

    final showLeave =
        !isAdminHere && myPlayer != null && !myPlayer!.isGuest && isExpanded;
    final showCreatorLeave = isAdminHere && isCreator && isExpanded;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.onDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isExpanded && !isDark
            ? [
                BoxShadow(
                  color: AppColors.darkApp.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _MiniGroupAvatar(
                        letter: groupName.isEmpty
                            ? 'G'
                            : groupName.characters.first,
                        isExpanded: isExpanded,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              groupName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.onDark
                                    : AppColors.lightText,
                              ),
                            ),
                            if (isAdminHere)
                              Text(
                                'Você administra',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.lightTextSecondary
                                      : AppColors.lightTextMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: isDark
                              ? AppColors.lightTextSecondary
                              : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                  if (isExpanded) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (isAdminHere) ...[
                            _SmallBtn(
                              label: 'Convidado',
                              icon: Icons.add,
                              variant: _SmallBtnVariant.secondary,
                              onTap: onAddGuest,
                            ),
                            _SmallBtn(
                              label: 'Convidar',
                              icon: Icons.person_add_alt_1_outlined,
                              variant: _SmallBtnVariant.primary,
                              onTap: onInvite,
                            ),
                          ],
                          if (showLeave || showCreatorLeave)
                            _SmallBtn(
                              label: 'Sair',
                              icon: Icons.logout,
                              variant: _SmallBtnVariant.danger,
                              onTap: onLeave,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isExpanded && groupContent != null)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderColor)),
              ),
              padding: const EdgeInsets.all(16),
              child: groupContent,
            ),
        ],
      ),
    );
  }
}

class _MiniGroupAvatar extends StatelessWidget {
  final String letter;
  final bool isExpanded;
  final bool isDark;

  const _MiniGroupAvatar({
    required this.letter,
    required this.isExpanded,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isExpanded
        ? (isDark ? AppColors.onDark : AppColors.lightText)
        : (isDark ? AppColors.darkBorder : AppColors.lightSeparator);

    final fg = isExpanded
        ? (isDark ? AppColors.lightText : AppColors.onDark)
        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        letter.toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: fg,
        ),
      ),
    );
  }
}

enum _SmallBtnVariant { primary, secondary, danger }

class _SmallBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final _SmallBtnVariant variant;
  final VoidCallback onTap;

  const _SmallBtn({
    required this.label,
    required this.icon,
    required this.variant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    late final Color bg;
    late final Color textColor;
    late final Color borderColor;

    switch (variant) {
      case _SmallBtnVariant.primary:
        bg = AppColors.lightText;
        textColor = AppColors.onDark;
        borderColor = AppColors.transparent;
        break;
      case _SmallBtnVariant.secondary:
        bg = isDark ? AppColors.darkBorder : AppColors.lightSeparator;
        textColor =
            isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
        borderColor =
            isDark ? AppColors.lightTextSecondary : AppColors.lightBorder;
        break;
      case _SmallBtnVariant.danger:
        bg = AppColors.transparent;
        textColor = AppColors.prototypeDanger;
        borderColor = AppColors.rose200;
        break;
    }

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: textColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group Content
// ─────────────────────────────────────────────────────────────────────────────

class _GroupContent extends StatefulWidget {
  final _GroupDto? group;
  final bool groupLoading;
  final String? groupError;
  final List<_PlayerDto> activePlayers;
  final List<_PlayerDto> guestPlayers;
  final List<_PlayerDto> inactivePlayers;
  final String activePlayerId;
  final bool isAdminHere;
  final bool isFinanceiroHere;
  final Map<String, _PaymentBadge> paymentMap;
  final GroupIcons icons;
  final bool isDark;
  final void Function(_PlayerDto) onEditPlayer;

  /// Mesma folha, seção de avaliações — a aba de origem decide.
  final void Function(_PlayerDto) onEditRatings;

  /// userId -> rótulo do papel ("Admin" / "Financeiro").
  final Map<String, List<String>> roleLabels;

  const _GroupContent({
    required this.group,
    required this.groupLoading,
    required this.groupError,
    required this.activePlayers,
    required this.guestPlayers,
    required this.inactivePlayers,
    required this.activePlayerId,
    required this.isAdminHere,
    required this.isFinanceiroHere,
    required this.paymentMap,
    this.icons = GroupIcons.defaults,
    required this.isDark,
    required this.onEditPlayer,
    required this.onEditRatings,
    this.roleLabels = const {},
  });

  @override
  State<_GroupContent> createState() => _GroupContentState();
}

class _GroupContentState extends State<_GroupContent> {
  int _tab = 0; // 0 = Jogadores, 1 = Avaliações
  int _playerFilter = 0; // 0 = Mensalistas, 1 = Convidados, 2 = Inativos

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final groupLoading = widget.groupLoading;
    final groupError = widget.groupError;
    final activePlayers = widget.activePlayers;
    final guestPlayers = widget.guestPlayers;
    final inactivePlayers = widget.inactivePlayers;
    final activePlayerId = widget.activePlayerId;
    final isAdminHere = widget.isAdminHere;
    final isFinanceiroHere = widget.isFinanceiroHere;
    final paymentMap = widget.paymentMap;
    final icons = widget.icons;
    final isDark = widget.isDark;
    final onEditPlayer = widget.onEditPlayer;
    final onEditRatings = widget.onEditRatings;
    final roleLabels = widget.roleLabels;

    if (groupError != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.rose50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.rose200),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline,
                size: 15, color: AppColors.prototypeDanger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                groupError,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.prototypeDanger),
              ),
            ),
          ],
        ),
      );
    }

    if (groupLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Carregando...'),
          ],
        ),
      );
    }

    if (group == null) return const SizedBox.shrink();

    if (activePlayers.isEmpty &&
        guestPlayers.isEmpty &&
        inactivePlayers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.group_outlined,
              size: 32,
              color: (isDark ? AppColors.onDark : AppColors.darkApp)
                  .withValues(alpha: 0.2),
            ),
            const SizedBox(height: 8),
            Text(
              'Nenhum jogador nesta patota.',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.lightTextSecondary
                    : AppColors.lightTextMuted,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Tab bar (admin only) ─────────────────────────────────────
        if (isAdminHere) ...[
          _GroupTabBar(
            tab: _tab,
            isDark: isDark,
            onTab: (t) => setState(() => _tab = t),
          ),
          const SizedBox(height: 16),
        ],

        // ── Tab content ──────────────────────────────────────────────
        if (_tab == 0 || !isAdminHere) ...[
          Row(
            children: [
              Expanded(
                child: _PlayerFilterChip(
                  label: 'Mensalistas',
                  count: activePlayers.length,
                  selected: _playerFilter == 0,
                  onTap: () => setState(() => _playerFilter = 0),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _PlayerFilterChip(
                  label: 'Convidados',
                  count: guestPlayers.length,
                  selected: _playerFilter == 1,
                  onTap: () => setState(() => _playerFilter = 1),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _PlayerFilterChip(
                  label: 'Inativos',
                  count: inactivePlayers.length,
                  selected: _playerFilter == 2,
                  onTap: () => setState(() => _playerFilter = 2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FilteredPlayerSection(
            filter: _playerFilter,
            activePlayers: activePlayers,
            guestPlayers: guestPlayers,
            inactivePlayers: inactivePlayers,
            activePlayerId: activePlayerId,
            isAdminHere: isAdminHere,
            isFinanceiroHere: isFinanceiroHere,
            paymentMap: paymentMap,
            icons: icons,
            isDark: isDark,
            onEdit: onEditPlayer,
            roleLabels: roleLabels,
          ),
        ] else ...[
          _RatingsTab(
            players: [...activePlayers, ...guestPlayers],
            activePlayerId: activePlayerId,
            isAdminHere: isAdminHere,
            isDark: isDark,
            onEdit: onEditRatings,
          ),
        ],
      ],
    );
  }
}

class _PlayerFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _PlayerFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        // `button.proto-chip`: 44 de altura, padding lateral 10, fonte 12/650.
        // A versão anterior usava labelLarge (14px) com padding 14, ficava larga
        // demais e o terceiro chip ("Inativos") saía da tela.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              // A contagem é informação funcional e nunca pode virar
              // reticências. Em larguras menores, reduzimos suavemente o
              // conjunto completo em vez de cortar justamente o número.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$label · $count',
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilteredPlayerSection extends StatelessWidget {
  final int filter;
  final List<_PlayerDto> activePlayers;
  final List<_PlayerDto> guestPlayers;
  final List<_PlayerDto> inactivePlayers;
  final String activePlayerId;
  final bool isAdminHere;
  final bool isFinanceiroHere;
  final Map<String, _PaymentBadge> paymentMap;
  final GroupIcons icons;
  final bool isDark;
  final void Function(_PlayerDto) onEdit;
  final Map<String, List<String>> roleLabels;

  const _FilteredPlayerSection({
    required this.filter,
    required this.activePlayers,
    required this.guestPlayers,
    required this.inactivePlayers,
    required this.activePlayerId,
    required this.isAdminHere,
    required this.isFinanceiroHere,
    required this.paymentMap,
    required this.icons,
    required this.isDark,
    required this.onEdit,
    this.roleLabels = const {},
  });

  @override
  Widget build(BuildContext context) {
    final players = switch (filter) {
      1 => guestPlayers,
      2 => inactivePlayers,
      _ => activePlayers,
    };
    final label = switch (filter) {
      1 => 'Convidados',
      2 => 'Inativos',
      _ => 'Mensalistas',
    };

    if (players.isEmpty) {
      // `.proto-empty` do protótipo: borda tracejada, ícone, título e uma linha
      // dizendo o que fazer. Antes era só uma frase solta no meio do card.
      final theme = Theme.of(context);
      final muted = theme.colorScheme.onSurfaceVariant;
      return Container(
        constraints: const BoxConstraints(minHeight: 150),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.borderDashedOf(theme.brightness),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              switch (filter) {
                1 => Icons.person_add_alt_1_outlined,
                2 => Icons.person_off_outlined,
                _ => Icons.groups_outlined,
              },
              size: 28,
              color: muted,
            ),
            const SizedBox(height: 8),
            Text(
              'Nenhum jogador em $label',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              switch (filter) {
                1 =>
                  'Convidados aparecem aqui depois de adicionados a uma partida.',
                2 => 'Jogadores que saíram da patota ficam listados aqui.',
                _ => 'Use Convidar para trazer alguém para a patota.',
              },
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ),
      );
    }

    return _PlayerSection(
      label: label,
      count: players.length,
      badgeTextColor: switch (filter) {
        1 => AppColors.warningLight,
        2 =>
          isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        _ =>
          AppColors.accentTextOf(isDark ? Brightness.dark : Brightness.light),
      },
      badgeLabelBg: switch (filter) {
        1 => AppColors.amber50,
        2 => isDark ? AppColors.darkBorder : AppColors.lightSeparator,
        _ => AppColors.accentBgOf(isDark ? Brightness.dark : Brightness.light),
      },
      roleLabels: roleLabels,
      players: players,
      activePlayerId: activePlayerId,
      isAdminHere: isAdminHere,
      isFinanceiroHere: isFinanceiroHere,
      paymentMap: paymentMap,
      icons: icons,
      dim: filter == 2,
      isDark: isDark,
      onEdit: onEdit,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group Tab Bar
// ─────────────────────────────────────────────────────────────────────────────

class _GroupTabBar extends StatelessWidget {
  final int tab;
  final bool isDark;
  final void Function(int) onTab;

  const _GroupTabBar({
    required this.tab,
    required this.isDark,
    required this.onTab,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.lightText : AppColors.lightSeparator,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _GroupTab(
            label: 'Jogadores',
            icon: Icons.group_outlined,
            active: tab == 0,
            isDark: isDark,
            onTap: () => onTab(0),
          ),
          _GroupTab(
            label: 'Avaliações',
            icon: Icons.star_rounded,
            active: tab == 1,
            isDark: isDark,
            onTap: () => onTab(1),
          ),
        ],
      ),
    );
  }
}

class _GroupTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;

  const _GroupTab({
    required this.label,
    required this.icon,
    required this.active,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? (isDark ? AppColors.darkBorder : AppColors.onDark)
                : AppColors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active && !isDark
                ? [
                    BoxShadow(
                      color: AppColors.darkApp.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: active
                    ? (isDark ? AppColors.onDark : AppColors.lightText)
                    : (isDark
                        ? AppColors.lightTextSecondary
                        : AppColors.lightTextMuted),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active
                      ? (isDark ? AppColors.onDark : AppColors.lightText)
                      : (isDark
                          ? AppColors.lightTextSecondary
                          : AppColors.lightTextMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ratings Tab
// ─────────────────────────────────────────────────────────────────────────────

class _RatingsTab extends StatefulWidget {
  final List<_PlayerDto> players;
  final String activePlayerId;
  final bool isAdminHere;
  final bool isDark;
  final void Function(_PlayerDto) onEdit;

  const _RatingsTab({
    required this.players,
    required this.activePlayerId,
    required this.isAdminHere,
    required this.isDark,
    required this.onEdit,
  });

  @override
  State<_RatingsTab> createState() => _RatingsTabState();
}

class _RatingsTabState extends State<_RatingsTab> {
  // 0=Overall, 1=Ataque, 2=Defesa, 3=Físico
  final int _sortBy = 0;

  double? _sortValue(_PlayerDto p) {
    switch (_sortBy) {
      case 1:
        return p.attackRating?.toDouble();
      case 2:
        return p.defenseRating?.toDouble();
      case 3:
        return p.overallRating?.toDouble();
      default:
        return p.computedOverall;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final mensalistas = widget.players.where((p) => !p.isGuest).toList();
    final guests = widget.players.where((p) => p.isGuest).toList();

    mensalistas.sort((a, b) {
      final va = _sortValue(a);
      final vb = _sortValue(b);
      if (va == null && vb == null) return a.name.compareTo(b.name);
      if (va == null) return 1;
      if (vb == null) return -1;
      return vb.compareTo(va);
    });

    guests.sort((a, b) {
      final ra = a.guestStarRating ?? -1;
      final rb = b.guestStarRating ?? -1;
      return rb.compareTo(ra);
    });

    if (mensalistas.isEmpty && guests.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 36,
                color: isDark
                    ? AppColors.lightTextSecondary
                    : AppColors.lightTextMuted),
            const SizedBox(height: 8),
            Text('Nenhum jogador ainda.',
                style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.lightTextSecondary
                        : AppColors.lightTextMuted)),
          ],
        ),
      );
    }

    // Protótipo: um card só, com título, contagem e as linhas separadas por
    // fio. As seções MENSALISTAS/CONVIDADOS com numeração de ranking saíram —
    // lá isso é uma lista de avaliações, não um pódio.
    final todos = [...mensalistas, ...guests];

    return Container(
      padding: const EdgeInsets.all(PrototypeLayout.cardPadding),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : AppColors.lightCard,
        borderRadius: BorderRadius.circular(PrototypeLayout.cardRadius),
        border: Border.all(
            color: isDark ? AppColors.slate700 : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrototypeSectionTitle(
            title: 'Avaliações dos jogadores',
            count: '${todos.length}',
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < todos.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: isDark ? AppColors.slate800 : AppColors.lightBorder,
              ),
            _RatingListRow(
              player: todos[i],
              isDark: isDark,
              onTap: widget.isAdminHere ? () => widget.onEdit(todos[i]) : null,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Linha da lista de avaliações
// ─────────────────────────────────────────────────────────────────────────────

/// `.proto-list-row` com a média à direita numa pastilha do accent.
///
/// O subtítulo lista os três atributos crus ("Geral 9 · Ataque 9 · Defesa 8")
/// e a pastilha traz a média. `overallRating` é o "Geral" — no site ele aparece
/// rotulado como "Físico", mas é o mesmo campo.
class _RatingListRow extends StatelessWidget {
  final _PlayerDto player;
  final bool isDark;
  final VoidCallback? onTap;

  const _RatingListRow({
    required this.player,
    required this.isDark,
    this.onTap,
  });

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// Só entram os atributos definidos — "Geral 9 · Ataque —" seria ruído.
  String get _attrs {
    final parts = <String>[
      if (player.overallRating != null) 'Geral ${player.overallRating}',
      if (player.attackRating != null) 'Ataque ${player.attackRating}',
      if (player.defenseRating != null) 'Defesa ${player.defenseRating}',
    ];
    return parts.isEmpty ? 'Sem avaliação' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avg = player.computedOverall;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PrototypeLayout.listRowRadius),
      child: Container(
        constraints:
            const BoxConstraints(minHeight: PrototypeLayout.listRowMinHeight),
        padding: PrototypeLayout.listRowPadding,
        child: Row(
          children: [
            UserProfileLink(
              userId: player.userId,
              child: player.photoUrl?.trim().isNotEmpty == true
                  ? AvatarWidget(
                      name: player.name,
                      photoUrl: player.photoUrl,
                      size: PrototypeLayout.avatarSize,
                      borderRadius: 8,
                    )
                  : Container(
                      width: PrototypeLayout.avatarSize,
                      height: PrototypeLayout.avatarSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.accentBgOf(theme.brightness),
                        borderRadius:
                            BorderRadius.circular(PrototypeLayout.avatarRadius),
                      ),
                      child: Text(
                        _initials(player.name),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentTextOf(theme.brightness),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: PrototypeLayout.rowGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserProfileLink(
                    userId: player.userId,
                    child: Text(
                      player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.onDark : AppColors.lightText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _attrs,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: isDark
                          ? AppColors.slate400
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (avg != null) ...[
              const SizedBox(width: 8),
              Container(
                height: 28,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.accentOf(theme.brightness),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  avg.toStringAsFixed(1).replaceAll('.', ','),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onAccentOf(theme.brightness),
                  ),
                ),
              ),
            ],
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  size: 20,
                  color:
                      isDark ? AppColors.slate500 : AppColors.lightTextMuted),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// A barra de ordenação, os cabeçalhos MENSALISTAS/CONVIDADOS, a linha com
// ranking numerado e o chip por atributo saíram com a repaginação da aba
// Avaliações: o protótipo mostra uma lista única, sem pódio e sem filtro.
// ─────────────────────────────────────────────────────────────────────────────

class _PlayerSection extends StatelessWidget {
  final String label;
  final int count;
  final Color badgeTextColor;
  final Color badgeLabelBg;
  final List<_PlayerDto> players;
  final String activePlayerId;
  final bool isAdminHere;
  final bool isFinanceiroHere;
  final Map<String, _PaymentBadge> paymentMap;
  final GroupIcons icons;
  final bool dim;
  final bool isDark;
  final void Function(_PlayerDto) onEdit;

  /// Ação à direita do título — `action="Adicionar"` no protótipo.
  final Map<String, List<String>> roleLabels;

  const _PlayerSection({
    required this.label,
    required this.count,
    required this.badgeTextColor,
    required this.badgeLabelBg,
    required this.players,
    required this.activePlayerId,
    required this.isAdminHere,
    required this.isFinanceiroHere,
    required this.paymentMap,
    this.icons = GroupIcons.defaults,
    required this.dim,
    required this.isDark,
    required this.onEdit,
    this.roleLabels = const {},
  });

  int _columnsForWidth(double width) {
    if (width >= 1200) return 4;
    if (width >= 900) return 3;
    if (width >= 560) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final cols = _columnsForWidth(constraints.maxWidth);
        final cardWidth =
            (constraints.maxWidth - ((cols - 1) * spacing)) / cols;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // `Proto.SectionTitle`: título em caixa normal (14px/750) com o
            // contador colado nele, e a ação alinhada à direita. A versão
            // anterior usava CAIXA ALTA com ícone colorido e o contador jogado
            // na outra ponta — parecia um cabeçalho de tabela, não uma seção.
            Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.onDark : AppColors.lightText,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeLabelBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkInputBorder
                          : AppColors.lightInputBorder,
                    ),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeTextColor,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: players
                  .map(
                    (p) => SizedBox(
                      width: cardWidth,
                      child: _PlayerCard(
                        player: p,
                        activePlayerId: activePlayerId,
                        isAdminHere: isAdminHere,
                        pmt: isFinanceiroHere ? paymentMap[p.id] : null,
                        roles: roleLabels[_normId(p.userId)] ?? const [],
                        icons: icons,
                        dim: dim,
                        isDark: isDark,
                        onEdit: onEdit,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      },
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final _PlayerDto player;
  final String activePlayerId;
  final bool isAdminHere;
  final _PaymentBadge? pmt; // null = sem permissão ou sem dados

  /// Papéis do jogador na patota ("Admin"/"Financeiro"). Pode ter os dois —
  /// cada um vira um chip ao lado do nome (igual à aba "Equipe").
  final List<String> roles;
  final GroupIcons icons;
  final bool dim;
  final bool isDark;
  final void Function(_PlayerDto) onEdit;

  const _PlayerCard({
    required this.player,
    required this.activePlayerId,
    required this.isAdminHere,
    required this.dim,
    required this.isDark,
    required this.onEdit,
    this.pmt,
    this.roles = const [],
    this.icons = GroupIcons.defaults,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = player.id == activePlayerId;
    final canEdit = isAdminHere;

    final parts = player.name.trim().split(RegExp(r'\s+'));
    final initials = parts.take(2).map((w) => w[0]).join().toUpperCase();

    Color avatarBg;
    Color avatarFg;

    // O protótipo usa um avatar só (`--accent-bg` / `--accent-text`) e marca o
    // usuário atual com o badge "Você", não trocando a cor. O verde daqui não
    // existe na paleta e brigava com o laranja do resto da tela.
    final brightness = isDark ? Brightness.dark : Brightness.light;
    if (isMe) {
      avatarBg = AppColors.accentBgOf(brightness);
      avatarFg = AppColors.accentTextOf(brightness);
    } else if (player.isGuest) {
      avatarBg = AppColors.amber50;
      avatarFg = AppColors.warningLight;
    } else {
      avatarBg = isDark ? AppColors.darkBorder : AppColors.lightBorder;
      avatarFg =
          isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    }

    final borderColor = isMe
        ? AppColors.accentOf(brightness)
        : (isDark
            ? AppColors.onDark.withValues(alpha: 0.08)
            : AppColors.lightBorder);

    return Opacity(
      opacity: dim ? 0.5 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.lightText : AppColors.onDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isMe ? 1.5 : 1),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: AppColors.darkApp.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserProfileLink(
                  userId: player.userId,
                  child: player.photoUrl?.trim().isNotEmpty == true
                      ? AvatarWidget(
                          name: player.name,
                          photoUrl: player.photoUrl,
                          size: 40,
                          borderRadius: 8,
                        )
                      : Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: avatarBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: avatarFg,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Protótipo: `.proto-player-name-with-icon` — o ícone de
                      // goleiro/jogador cola no nome. O `Expanded` de antes
                      // esticava o texto e jogava o ícone na outra ponta da
                      // linha, longe de quem ele qualifica.
                      Row(
                        children: [
                          Flexible(
                            child: UserProfileLink(
                              userId: player.userId,
                              child: Text(
                                player.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.onDark
                                      : AppColors.lightText,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          renderGroupIcon(
                            player.isGoalkeeper
                                ? icons.goalkeeper
                                : icons.player,
                            size: 14,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                          // Mesmo estilo da aba "Equipe" em Configurações:
                          // Adm. = azul (info), Fin. = verde (emerald500).
                          // Um chip por papel — mostra os dois se for ambos.
                          for (final role in roles) ...[
                            const SizedBox(width: 6),
                            Builder(builder: (_) {
                              final isAdm = role == 'Admin';
                              final color =
                                  isAdm ? AppColors.info : AppColors.emerald500;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withAlpha(30),
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: color.withAlpha(70)),
                                ),
                                child: Text(
                                  isAdm ? 'Adm.' : 'Fin.',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                    height: 1.2,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                      // `.proto-group-player-details`: handle, status
                      // financeiro e estrelas convivem na MESMA linha do
                      // subtítulo, com quebra quando não cabe.
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (player.userName != null &&
                                player.userName!.isNotEmpty)
                              Text(
                                '@${player.userName}',
                                // #94A3B8 sobre branco dava 2.56:1 — reprovado
                                // em contraste e praticamente ilegível. Os
                                // tokens do protótipo dão 5.6:1 e 5.8:1.
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted,
                                ),
                              ),
                            if (pmt != null) _PaymentBadgeWidget(pmt: pmt!),
                            if (player.isGuest &&
                                player.guestStarRating != null &&
                                isAdminHere)
                              _StarDisplay(value: player.guestStarRating!),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isMe)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          // `Proto.Badge tone="accent"` no protótipo.
                          color: AppColors.accentBgOf(
                              isDark ? Brightness.dark : Brightness.light),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          'Você',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.accentTextOf(
                                isDark ? Brightness.dark : Brightness.light),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (canEdit) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => onEdit(player),
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: Icon(
                            Icons.edit_outlined,
                            size: 13,
                            color: isDark
                                ? AppColors.lightTextSecondary
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentBadgeWidget extends StatelessWidget {
  final _PaymentBadge pmt;
  const _PaymentBadgeWidget({required this.pmt});

  @override
  Widget build(BuildContext context) {
    final total = pmt.pendingMonths + pmt.pendingExtras;
    if (total == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.emerald50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.green200),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 11, color: AppColors.accent),
            SizedBox(width: 4),
            Text(
              'Em dia',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryPressed,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.rose50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.rose200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline,
              size: 11, color: AppColors.prototypeDanger),
          const SizedBox(width: 4),
          Text(
            '$total pendência${total != 1 ? 's' : ''}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.prototypeDanger,
            ),
          ),
        ],
      ),
    );
  }
}

class _StarDisplay extends StatelessWidget {
  final int value;

  const _StarDisplay({required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        5,
        (i) => Text(
          '★',
          style: TextStyle(
            fontSize: 13,
            color: i < value ? AppColors.warning : AppColors.lightBorder,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared UI
// ─────────────────────────────────────────────────────────────────────────────

class _GradientCard extends StatelessWidget {
  final Widget child;
  final bool dotPattern;

  const _GradientCard({
    required this.child,
    this.dotPattern = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.lightText,
            AppColors.darkCard,
            AppColors.lightText
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkApp.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      // CustomPaint like this gives the child proper tight constraints
      // (unlike Stack which passes loose constraints to non-positioned children)
      child: dotPattern
          ? CustomPaint(painter: _DotPatternPainter(), child: child)
          : child,
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.onDark.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GroupAvatar extends StatelessWidget {
  final String letter;
  final double size;
  final double radius;

  const _GroupAvatar({
    required this.letter,
    this.size = 36,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.onDark.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.onDark.withValues(alpha: 0.2)),
      ),
      alignment: Alignment.center,
      child: Text(
        letter.toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.35,
          fontWeight: FontWeight.w900,
          color: AppColors.onDark,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modals
// ─────────────────────────────────────────────────────────────────────────────

class _ModalSheet extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _ModalSheet({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.onDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.onDark.withValues(alpha: 0.2)
                      : AppColors.darkApp.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isDark;

  const _SheetHeader({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.isDark,
    this.iconColor = AppColors.onDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? AppColors.onDark.withValues(alpha: 0.08)
                : AppColors.darkApp.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.onDark : AppColors.lightText,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.lightPlaceholder
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool isDark;

  const _FieldLabel(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.lightBorder : AppColors.darkBorder,
      ),
    );
  }
}

class _AppInput extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final bool enabled;
  final bool isDark;
  final ValueChanged<String>? onSubmitted;

  const _AppInput({
    required this.controller,
    required this.enabled,
    required this.isDark,
    this.hint,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      onSubmitted: onSubmitted,
      maxLines: 1,
      style: TextStyle(
        color: isDark ? AppColors.onDark : AppColors.lightText,
      ),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: isDark ? AppColors.lightText : AppColors.lightSubtle,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? AppColors.onDark.withValues(alpha: 0.08)
                : AppColors.lightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? AppColors.onDark.withValues(alpha: 0.08)
                : AppColors.lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.infoLight),
        ),
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _PrimaryBtn({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lightText,
          foregroundColor: AppColors.onDark,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.onDark),
              )
            : Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _Toggle({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Switch(value: value, onChanged: onChanged);
  }
}

class _StarRatingWidget extends StatelessWidget {
  final int? value;
  final bool disabled;
  final ValueChanged<int> onChanged;

  const _StarRatingWidget({
    required this.value,
    required this.disabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: List.generate(
        5,
        (index) {
          final star = index + 1;
          final selected = value != null && star <= value!;
          return InkWell(
            onTap: disabled ? null : () => onChanged(star),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Text(
                '★',
                style: TextStyle(
                  fontSize: 24,
                  color:
                      selected ? AppColors.warning : AppColors.lightTextMuted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rating Slider (mensalistas: 0–10 per category)
// ─────────────────────────────────────────────────────────────────────────────

/// Bloco de um atributo, como no protótipo: caixa de ícone na cor do atributo,
/// rótulo e descrição, stepper −/+ à direita e o slider abaixo entre 0 e 10.
///
/// Antes era uma linha compacta com o número num chip. O stepper foi somado
/// porque acertar um valor exato arrastando um slider de 10 divisões num
/// celular é impreciso — o toque cobre mais de uma divisão.
class _RatingSlider extends StatelessWidget {
  final String label;
  final String icon;
  final String? description;
  final Color color;
  final int? value;
  final bool disabled;
  final bool isDark;
  final ValueChanged<int> onChanged;

  const _RatingSlider({
    required this.label,
    required this.icon,
    required this.color,
    required this.value,
    required this.disabled,
    required this.isDark,
    required this.onChanged,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = value ?? 0;
    final surface = isDark ? AppColors.slate800 : AppColors.lightSubtle;
    final border = isDark ? AppColors.slate700 : AppColors.lightBorder;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Text(icon, style: const TextStyle(fontSize: 15)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.onDark : AppColors.lightText,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        description!,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: isDark
                              ? AppColors.slate400
                              : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Stepper(
                value: value,
                color: color,
                isDark: isDark,
                disabled: disabled,
                onChanged: onChanged,
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor:
                  isDark ? AppColors.slate700 : AppColors.slate200,
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.12),
              trackHeight: 5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: displayValue.toDouble(),
              min: 0,
              max: 10,
              divisions: 10,
              label: '$displayValue',
              onChanged: disabled ? null : (v) => onChanged(v.round()),
            ),
          ),
          // Réguas 0 e 10, como no protótipo — sem elas a escala do slider
          // fica implícita.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0', style: _scaleStyle),
                Text('10', style: _scaleStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _scaleStyle => TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.slate500 : AppColors.lightTextMuted,
      );
}

/// Stepper −/+ com o valor no meio, na cor do atributo.
class _Stepper extends StatelessWidget {
  final int? value;
  final Color color;
  final bool isDark;
  final bool disabled;
  final ValueChanged<int> onChanged;

  const _Stepper({
    required this.value,
    required this.color,
    required this.isDark,
    required this.disabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final v = value ?? 0;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : AppColors.lightCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isDark ? AppColors.slate700 : AppColors.lightBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(
            icon: Icons.remove,
            // Vai até 0, não até null: limpar é papel do "Limpar avaliações".
            onTap: disabled || v <= 0 ? null : () => onChanged(v - 1),
            isDark: isDark,
          ),
          SizedBox(
            width: 26,
            child: Text(
              value != null ? '$v' : '—',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: value != null
                    ? color
                    : (isDark ? AppColors.slate500 : AppColors.lightTextMuted),
              ),
            ),
          ),
          _StepBtn(
            icon: Icons.add,
            onTap: disabled || v >= 10 ? null : () => onChanged(v + 1),
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isDark;

  const _StepBtn(
      {required this.icon, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 32,
        height: 34,
        child: Icon(
          icon,
          size: 16,
          color: onTap == null
              ? (isDark ? AppColors.slate700 : AppColors.slate300)
              : (isDark ? AppColors.slate300 : AppColors.lightTextSecondary),
        ),
      ),
    );
  }
}

/// Cabeçalho da seção de avaliações: média atual e ação de limpar.
class _RatingsHeader extends StatelessWidget {
  final double? average;
  final bool isDark;
  final VoidCallback? onClear;

  const _RatingsHeader({
    required this.average,
    required this.isDark,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final avg = average;
    return Row(
      children: [
        Expanded(
          child: Text(
            avg == null
                ? 'Sem avaliação'
                : 'Média atual: ${avg.toStringAsFixed(1).replaceAll('.', ',')}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.slate300 : AppColors.lightTextSecondary,
            ),
          ),
        ),
        if (onClear != null)
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: AppColors.dangerOf(
                  isDark ? Brightness.dark : Brightness.light),
            ),
            child: const Text('Limpar avaliações',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}

/// Nota de rodapé explicando para que servem as notas.
class _RatingsFootnote extends StatelessWidget {
  final bool isDark;

  const _RatingsFootnote({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? AppColors.slate400 : AppColors.lightTextMuted;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.lightSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isDark ? AppColors.slate700 : AppColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 15, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'As notas ajudam os algoritmos a distribuir ataque, defesa e nível geral.',
              style: TextStyle(fontSize: 11, height: 1.4, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Guest
// ─────────────────────────────────────────────────────────────────────────────

class _AddGuestSheet extends StatefulWidget {
  final Future<void> Function(String name, bool isGoalkeeper, int? starRating)
      onSubmit;

  /// Renderizado dentro de outra folha (a de convite), sem a moldura e o
  /// cabeçalho próprios. Evita duplicar o formulário de convidado em dois
  /// lugares que inevitavelmente divergiriam.
  final bool embedded;

  const _AddGuestSheet({required this.onSubmit, this.embedded = false});

  @override
  State<_AddGuestSheet> createState() => _AddGuestSheetState();
}

class _AddGuestSheetState extends State<_AddGuestSheet> {
  final _nameCtrl = TextEditingController();
  bool _isGoalkeeper = false;
  int? _starRating;
  bool _loading = false;
  String? _err;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _err = 'Nome é obrigatório.');
      return;
    }

    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      await widget.onSubmit(name, _isGoalkeeper, _starRating);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _err = _extractError(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final body = SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.embedded)
            _SheetHeader(
              icon: Icons.add,
              iconBg: AppColors.warning,
              title: 'Adicionar convidado',
              subtitle: 'Sem conta no sistema',
              isDark: isDark,
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FieldLabel('Nome do convidado', isDark: isDark),
                const SizedBox(height: 6),
                _AppInput(
                  controller: _nameCtrl,
                  hint: 'Ex: Zé da Pelada',
                  enabled: !_loading,
                  isDark: isDark,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _Toggle(
                      value: _isGoalkeeper,
                      onChanged: _loading
                          ? null
                          : (v) => setState(() => _isGoalkeeper = v),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Goleiro',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.lightBorder
                            : AppColors.darkBorder,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _FieldLabel('Nível estimado (opcional)', isDark: isDark),
                const SizedBox(height: 8),
                _StarRatingWidget(
                  value: _starRating,
                  disabled: _loading,
                  onChanged: (v) => setState(() => _starRating = v),
                ),
                if (_err != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _err!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.prototypeDanger,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _PrimaryBtn(
                  label: _loading ? 'Adicionando...' : 'Adicionar à patota',
                  loading: _loading,
                  onTap: _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Embutido, quem desenha a moldura é a folha de convite.
    if (widget.embedded) return body;
    return _ModalSheet(isDark: isDark, child: body);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Player
// ─────────────────────────────────────────────────────────────────────────────

/// Qual parte do jogador a folha edita.
///
/// A aba Jogadores cuida do cadastro; a aba Avaliações, das notas. Antes as
/// duas abriam a folha inteira, então quem clicava numa nota caía em campos de
/// nome e status, e quem editava o cadastro via sliders de avaliação.
enum _EditSection { player, ratings }

class _EditPlayerSheet extends StatefulWidget {
  final _PlayerDto player;
  final bool isAdmin;
  final Future<void> Function(Map<String, dynamic>) onSaved;

  final _EditSection section;

  /// Called when admin confirms removing the player from the group. Null = feature not available.
  final Future<void> Function()? onRemove;

  const _EditPlayerSheet({
    required this.player,
    required this.isAdmin,
    required this.onSaved,
    this.section = _EditSection.player,
    this.onRemove,
  });

  @override
  State<_EditPlayerSheet> createState() => _EditPlayerSheetState();
}

class _EditPlayerSheetState extends State<_EditPlayerSheet> {
  late final TextEditingController _nameCtrl;
  late bool _isGuest;
  late bool _isActive;
  late bool _isGoalkeeper;
  // mensalista ratings (1–10, null = not set)
  int? _attackRating;
  int? _defenseRating;
  int? _overallRating;
  // guest rating
  int? _starRating;
  bool _loading = false;
  bool _removing = false;
  bool _confirmRemove = false;
  String? _err;

  bool get _hasAnyRating =>
      _attackRating != null || _defenseRating != null || _overallRating != null;

  /// Média dos atributos **definidos** — mesma regra do `computeOverall` do
  /// site e do `computedOverall` do DTO. Dividir sempre por três puniria quem
  /// só teve um atributo avaliado.
  double? get _currentAverage {
    final vals = [
      if (_overallRating != null) _overallRating!,
      if (_attackRating != null) _attackRating!,
      if (_defenseRating != null) _defenseRating!,
    ];
    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  void _clearRatings() => setState(() {
        _attackRating = null;
        _defenseRating = null;
        _overallRating = null;
      });

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.player.name);
    _isGuest = widget.player.isGuest;
    _isActive = widget.player.status == 1;
    _isGoalkeeper = widget.player.isGoalkeeper;
    _attackRating = widget.player.attackRating;
    _defenseRating = widget.player.defenseRating;
    _overallRating = widget.player.overallRating;
    _starRating = widget.player.guestStarRating;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _remove() async {
    setState(() {
      _removing = true;
      _err = null;
    });
    try {
      await widget.onRemove!();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _err = _extractError(e);
        _confirmRemove = false;
      });
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _err = 'Nome é obrigatório.');
      return;
    }

    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final dto = <String, dynamic>{
        'name': name,
        'isGoalkeeper': _isGoalkeeper,
      };

      if (widget.isAdmin) {
        dto['status'] = _isActive ? 1 : 2;
        dto['isGuest'] = _isGuest;
        if (_isGuest) {
          if (_starRating != null) dto['guestStarRating'] = _starRating;
        } else {
          // Enviados mesmo quando `null`. Omitir a chave faria o backend
          // manter o valor antigo, e aí "Limpar avaliações" não limparia
          // nada — a nota voltaria no próximo carregamento.
          dto['attackRating'] = _attackRating;
          dto['defenseRating'] = _defenseRating;
          dto['overallRating'] = _overallRating;
        }
      }

      await widget.onSaved(dto);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _err = _extractError(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRatings = widget.section == _EditSection.ratings;

    return _ModalSheet(
      isDark: isDark,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(
              icon:
                  isRatings ? Icons.star_outline_rounded : Icons.edit_outlined,
              iconBg: isDark ? AppColors.onDark : AppColors.lightText,
              iconColor: isDark ? AppColors.lightText : AppColors.onDark,
              title: isRatings ? 'Avaliar jogador' : 'Editar jogador',
              subtitle: widget.player.name,
              isDark: isDark,
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isRatings) ...[
                    _FieldLabel('Nome', isDark: isDark),
                    const SizedBox(height: 6),
                    _AppInput(
                      controller: _nameCtrl,
                      enabled: !_loading,
                      isDark: isDark,
                      onSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _Toggle(
                          value: _isGoalkeeper,
                          onChanged: _loading
                              ? null
                              : (v) => setState(() => _isGoalkeeper = v),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Goleiro',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? AppColors.lightBorder
                                : AppColors.darkBorder,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (widget.isAdmin) ...[
                    if (!isRatings) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _Toggle(
                            value: _isActive,
                            onChanged: _loading
                                ? null
                                : (v) => setState(() => _isActive = v),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Ativo',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? AppColors.lightBorder
                                  : AppColors.darkBorder,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _Toggle(
                            value: _isGuest,
                            onChanged: _loading
                                ? null
                                : (v) => setState(() => _isGuest = v),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Convidado',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? AppColors.lightBorder
                                  : AppColors.darkBorder,
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Avaliação: ratings para mensalistas, estrelas para
                    // convidados. Na seção de cadastro ela não aparece.
                    if (isRatings && !_isGuest) ...[
                      const SizedBox(height: 16),
                      // Média atual + "Limpar avaliações", como no protótipo.
                      _RatingsHeader(
                        average: _currentAverage,
                        isDark: isDark,
                        onClear:
                            _hasAnyRating && !_loading ? _clearRatings : null,
                      ),
                      const SizedBox(height: 12),
                      // Ordem e rótulos do protótipo: Geral vem primeiro.
                      // `overallRating` é o "Geral" — o site o rotula como
                      // "Físico", mas é o mesmo campo, e a média de exibição
                      // na lista já o trata como um dos três atributos.
                      _RatingSlider(
                        label: 'Geral',
                        icon: '⭐',
                        description:
                            'Visão geral do jogador e peso principal no equilíbrio.',
                        color: AppColors.warning,
                        value: _overallRating,
                        disabled: _loading,
                        isDark: isDark,
                        onChanged: (v) => setState(() => _overallRating = v),
                      ),
                      const SizedBox(height: 10),
                      _RatingSlider(
                        label: 'Ataque',
                        icon: '⚔️',
                        description:
                            'Finalização, drible e posicionamento ofensivo.',
                        color: AppColors.prototypeDanger,
                        value: _attackRating,
                        disabled: _loading,
                        isDark: isDark,
                        onChanged: (v) => setState(() => _attackRating = v),
                      ),
                      const SizedBox(height: 10),
                      _RatingSlider(
                        label: 'Defesa',
                        icon: '🛡️',
                        description:
                            'Marcação, interceptação e posicionamento defensivo.',
                        color: AppColors.info,
                        value: _defenseRating,
                        disabled: _loading,
                        isDark: isDark,
                        onChanged: (v) => setState(() => _defenseRating = v),
                      ),
                      const SizedBox(height: 12),
                      _RatingsFootnote(isDark: isDark),
                    ] else if (isRatings) ...[
                      const SizedBox(height: 16),
                      _FieldLabel('Nível estimado (estrelas)', isDark: isDark),
                      const SizedBox(height: 8),
                      _StarRatingWidget(
                        value: _starRating,
                        disabled: _loading,
                        onChanged: (v) => setState(() => _starRating = v),
                      ),
                    ],
                  ],
                  if (_err != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _err!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.prototypeDanger,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _PrimaryBtn(
                    label: _loading
                        ? 'Salvando...'
                        : (isRatings ? 'Salvar avaliação' : 'Salvar'),
                    loading: _loading || _removing,
                    onTap: _save,
                  ),

                  // ── Remover da patota (admin + não-guest + tem userId) ──
                  // Remover da patota é ação de cadastro, não de avaliação.
                  if (widget.onRemove != null && !isRatings) ...[
                    const SizedBox(height: 10),
                    if (!_confirmRemove)
                      SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: (_loading || _removing)
                              ? null
                              : () => setState(() => _confirmRemove = true),
                          icon: const Icon(Icons.person_remove_outlined,
                              size: 15),
                          label: const Text('Remover da patota'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.prototypeDanger,
                            side: const BorderSide(color: AppColors.rose200),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.dangerBackground
                              : AppColors.rose50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? AppColors.prototypeDanger
                                : AppColors.rose200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    size: 14, color: AppColors.prototypeDanger),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${widget.player.name} voltará a ser convidado '
                                    'e perderá o vínculo com a conta. '
                                    'O histórico de partidas é preservado.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.prototypeDanger,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _removing
                                      ? null
                                      : () => setState(
                                          () => _confirmRemove = false),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    side: BorderSide(
                                        color: isDark
                                            ? AppColors.lightTextSecondary
                                            : AppColors.lightTextMuted),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  child: Text(
                                    'Cancelar',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? AppColors.lightPlaceholder
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _removing ? null : _remove,
                                  icon: _removing
                                      ? const SizedBox(
                                          width: 13,
                                          height: 13,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.onDark),
                                        )
                                      : const Icon(Icons.person_remove_outlined,
                                          size: 13),
                                  label: Text(
                                      _removing ? 'Removendo...' : 'Confirmar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.prototypeDanger,
                                    foregroundColor: AppColors.onDark,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invite
// ─────────────────────────────────────────────────────────────────────────────

class _PendingInviteItem {
  final String inviteId;
  final String userId;
  final String fullName;
  final String userName;

  const _PendingInviteItem({
    required this.inviteId,
    required this.userId,
    required this.fullName,
    required this.userName,
  });

  factory _PendingInviteItem.fromJson(Map<String, dynamic> j) =>
      _PendingInviteItem(
        inviteId: j['id'] as String? ?? '',
        userId: j['targetUserId'] as String? ?? '',
        fullName: j['targetUserFullName'] as String? ?? '',
        userName: j['targetUserLogin'] as String? ?? '',
      );
}

class _InviteSheet extends StatefulWidget {
  final Dio dio;
  final String groupId;
  final Set<String> existingUserIds;
  final List<_PlayerDto> guestPlayers;
  final Future<void> Function() onInvited;

  /// Cria um convidado — o outro caminho desta mesma folha.
  final Future<void> Function(String name, bool isGoalkeeper, int? starRating)
      onAddGuest;

  const _InviteSheet({
    required this.dio,
    required this.groupId,
    required this.existingUserIds,
    required this.guestPlayers,
    required this.onInvited,
    required this.onAddGuest,
  });

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  /// "Usuário" vincula uma conta existente; "Convidado" cria um perfil avulso.
  /// Os dois eram folhas separadas, alcançadas por botões diferentes — no
  /// protótipo vivem na mesma, porque a decisão é uma só: quem entra agora.
  static const _modeUser = 'Usuário';
  static const _modeGuest = 'Convidado';
  String _mode = _modeUser;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  bool _pendingLoading = false;
  bool _hasTried = false;
  String? _err;
  List<_UserResult> _results = [];
  List<_PendingInviteItem> _pendingItems = [];

  Set<String> get _pendingUserIds => _pendingItems.map((e) => e.userId).toSet();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onTextChanged);
    _loadPendingInvites();
  }

  Future<void> _loadPendingInvites() async {
    if (mounted) setState(() => _pendingLoading = true);
    try {
      final res = await widget.dio
          .get(ApiConstants.groupPendingInvites(widget.groupId));
      final raw = _GroupsPageState._unwrap(res.data);
      final list = raw is List ? raw : [];
      final items = list
          .map((e) => _PendingInviteItem.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() => _pendingItems = items);
    } catch (_) {
      // silently ignore
    } finally {
      if (mounted) setState(() => _pendingLoading = false);
    }
  }

  void _onTextChanged() {
    _debounce?.cancel();
    final term = _searchCtrl.text.trim();
    if (term.length < 2) {
      setState(() {
        _results = [];
        _err = null;
        _hasTried = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onTextChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final term = _searchCtrl.text.trim();
    if (term.length < 2) return;

    setState(() {
      _loading = true;
      _err = null;
      _hasTried = true;
    });

    try {
      final res = await widget.dio.get(
        ApiConstants.usersListSearch(term, 20),
      );

      // Response envelope: { success, data: { page, pageSize, total, items: [...] } }
      final envelope = _GroupsPageState._unwrap(res.data);
      final items = (envelope is Map ? envelope['items'] : null) as List? ?? [];
      final list = items
          .map((e) => _UserResult.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) setState(() => _results = list);
    } catch (e) {
      if (mounted) setState(() => _err = _extractError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _invite(_UserResult user) async {
    // Captura antes de qualquer await para funcionar mesmo após Navigator.pop
    final messenger = ScaffoldMessenger.of(context);
    final displayName =
        user.fullName.isNotEmpty ? user.fullName : user.userName;

    // If there are unlinked guests, ask whether to associate this user with one.
    String? guestPlayerId;
    if (widget.guestPlayers.isNotEmpty && mounted) {
      final picked = await showDialog<_PlayerDto?>(
        context: context,
        builder: (_) => _LinkGuestDialog(
          userName: user.fullName.isNotEmpty ? user.fullName : user.userName,
          guests: widget.guestPlayers,
        ),
      );
      // null  = dialog dismissed (cancel) → abort invite
      // _sentinel means "no link, invite as new member"
      // a _PlayerDto means link to that guest
      if (picked == _LinkGuestDialog.sentinel) {
        guestPlayerId = null; // no linking, proceed normally
      } else if (picked != null) {
        guestPlayerId = picked.id;
      } else {
        return; // user dismissed dialog — do nothing
      }
    }

    setState(() => _loading = true);

    try {
      await widget.dio.post(
        ApiConstants.groupInvites(widget.groupId),
        data: {
          'targetUserId': user.id,
          if (guestPlayerId != null) 'guestPlayerId': guestPlayerId,
        },
      );

      await _loadPendingInvites();
      await widget.onInvited();
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text('Convite enviado para $displayName.'),
          backgroundColor: AppColors.primaryPressed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      final errMsg = _extractError(e);
      final isPending = errMsg.toLowerCase().contains('pendente');
      if (isPending) await _loadPendingInvites();
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(errMsg),
          backgroundColor:
              isPending ? AppColors.warning : AppColors.prototypeDanger,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelInvite(_PendingInviteItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final displayName =
        item.fullName.isNotEmpty ? item.fullName : item.userName;
    try {
      await widget.dio.delete(
        ApiConstants.groupCancelInvite(widget.groupId, item.inviteId),
      );
      await _loadPendingInvites();
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text('Convite de $displayName cancelado.'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
    } catch (e) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(_extractError(e)),
          backgroundColor: AppColors.prototypeDanger,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: _ModalSheet(
        isDark: isDark,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(
              icon: Icons.person_add_alt_1_outlined,
              iconBg: AppColors.lightText,
              title: 'Convidar jogador',
              subtitle: 'Vincule uma conta ou crie um perfil convidado.',
              isDark: isDark,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: PrototypeSegmented(
                items: const [_modeUser, _modeGuest],
                value: _mode,
                semanticLabel: 'Tipo de convite',
                onChanged: (m) => setState(() => _mode = m),
              ),
            ),
            if (_mode == _modeGuest)
              _AddGuestSheet(onSubmit: widget.onAddGuest, embedded: true)
            else
              ..._userModeChildren(isDark),
          ],
        ),
      ),
    );
  }

  /// Busca de usuário + convites pendentes, o conteúdo do modo "Usuário".
  List<Widget> _userModeChildren(bool isDark) {
    return [
      TabBar(
        tabs: [
          const Tab(text: 'Convidar'),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Pendentes'),
                if (_pendingItems.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_pendingItems.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        labelColor: isDark ? AppColors.onDark : AppColors.lightText,
        unselectedLabelColor:
            isDark ? AppColors.lightTextSecondary : AppColors.lightTextMuted,
        indicatorColor: AppColors.lightText,
        dividerColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      ),
      Flexible(
        child: TabBarView(
          children: [
            _buildSearchTab(isDark),
            _buildPendingTab(isDark),
          ],
        ),
      ),
    ];
  }

  Widget _buildSearchTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _AppInput(
            controller: _searchCtrl,
            hint: 'Pesquisar...',
            enabled: !_loading,
            isDark: isDark,
          ),
          if (_err != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_err!,
                  style: const TextStyle(color: AppColors.prototypeDanger)),
            ),
          ],
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _results.isEmpty
                    ? _hasTried
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              'Nenhum resultado.',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.lightPlaceholder
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          )
                        : const SizedBox.shrink()
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final user = _results[index];
                          final name = user.fullName.isEmpty
                              ? user.userName
                              : user.fullName;
                          final isMember =
                              widget.existingUserIds.contains(user.id);
                          final isPending = _pendingUserIds.contains(user.id);
                          return _buildUserRow(
                            isDark: isDark,
                            name: name,
                            userName: user.userName,
                            trailing: isMember
                                ? _StatusBadge(label: 'Membro', isDark: isDark)
                                : isPending
                                    ? _StatusBadge(
                                        label: 'Pendente',
                                        isDark: isDark,
                                        color: AppColors.warning,
                                      )
                                    : ElevatedButton(
                                        onPressed: _loading
                                            ? null
                                            : () => _invite(user),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.lightText,
                                          foregroundColor: AppColors.onDark,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                        child: const Text('Convidar',
                                            style: TextStyle(fontSize: 13)),
                                      ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTab(bool isDark) {
    if (_pendingLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pendingItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Nenhum convite pendente.',
            style: TextStyle(
              color: isDark
                  ? AppColors.lightPlaceholder
                  : AppColors.lightTextSecondary,
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _pendingItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = _pendingItems[i];
        final name = item.fullName.isNotEmpty ? item.fullName : item.userName;
        return _buildUserRow(
          isDark: isDark,
          name: name,
          userName: item.userName,
          trailing: TextButton.icon(
            onPressed: () => _cancelInvite(item),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.prototypeDanger,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Cancelar', style: TextStyle(fontSize: 13)),
          ),
        );
      },
    );
  }

  Widget _buildUserRow({
    required bool isDark,
    required String name,
    required String userName,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.lightText : AppColors.lightSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppColors.onDark.withValues(alpha: 0.08)
              : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor:
                isDark ? AppColors.darkBorder : AppColors.lightBorder,
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.onDark : AppColors.lightText,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.onDark : AppColors.lightText,
                  ),
                ),
                Text(
                  '@$userName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.lightPlaceholder
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status badge (Membro / Pendente)
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final bool isDark;
  final Color? color;

  const _StatusBadge({required this.label, required this.isDark, this.color});

  @override
  Widget build(BuildContext context) {
    final bg = color != null
        ? color!.withValues(alpha: 0.15)
        : (isDark ? AppColors.darkCard : AppColors.lightBorder);
    final fg = color ??
        (isDark ? AppColors.lightPlaceholder : AppColors.lightTextSecondary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Link-guest dialog  (shown during invite flow when guests exist)
// ─────────────────────────────────────────────────────────────────────────────

class _LinkGuestDialog extends StatelessWidget {
  final String userName;
  final List<_PlayerDto> guests;

  /// Sentinel returned when the user chooses "Não vincular".
  static const _PlayerDto sentinel = _PlayerDto(
    id: '__no_link__',
    name: '',
    skillPoints: 0,
    isGoalkeeper: false,
    isGuest: true,
    status: 0,
  );

  const _LinkGuestDialog({
    required this.userName,
    required this.guests,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCard : AppColors.onDark;
    final border = isDark
        ? AppColors.onDark.withValues(alpha: 0.08)
        : AppColors.lightBorder;

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.link_rounded,
                      size: 18, color: AppColors.warning),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vincular a convidado?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? AppColors.onDark : AppColors.lightText,
                        ),
                      ),
                      Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.lightPlaceholder
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Deseja associar este usuário a um convidado já existente na patota?',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // ── Guest list ───────────────────────────────────────────
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: guests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final g = guests[i];
                  return InkWell(
                    onTap: () => Navigator.pop(context, g),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.lightText
                            : AppColors.lightSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.amber50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              g.name.isNotEmpty
                                  ? g.name.characters.first.toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.warningLight,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              g.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.onDark
                                    : AppColors.lightText,
                              ),
                            ),
                          ),
                          if (g.isGoalkeeper) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.shield_outlined,
                                size: 13,
                                color: isDark
                                    ? AppColors.lightTextSecondary
                                    : AppColors.lightTextMuted),
                          ],
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right_rounded,
                              size: 18,
                              color: isDark
                                  ? AppColors.lightTextSecondary
                                  : AppColors.lightTextMuted),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // ── Actions ──────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, null),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.lightPlaceholder
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, sentinel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lightText,
                      foregroundColor: AppColors.onDark,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Não vincular',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Leave dialog
// ─────────────────────────────────────────────────────────────────────────────

class _LeaveConfirmDialog extends StatefulWidget {
  final Future<void> Function() onConfirm;

  const _LeaveConfirmDialog({
    required this.onConfirm,
  });

  @override
  State<_LeaveConfirmDialog> createState() => _LeaveConfirmDialogState();
}

class _LeaveConfirmDialogState extends State<_LeaveConfirmDialog> {
  bool _loading = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await widget.onConfirm();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkCard : AppColors.onDark,
      title: Text(
        'Sair da patota?',
        style: TextStyle(
          color: isDark ? AppColors.onDark : AppColors.lightText,
        ),
      ),
      content: Text(
        'Essa ação remove você da patota atual.',
        style: TextStyle(
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.prototypeDanger,
            foregroundColor: AppColors.onDark,
          ),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onDark,
                  ),
                )
              : const Text('Sair'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create Group Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CreateGroupSheet extends StatefulWidget {
  final Future<void> Function(String name) onSubmit;
  const _CreateGroupSheet({required this.onSubmit});

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _err;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _err = 'Nome é obrigatório.');
      return;
    }
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      await widget.onSubmit(name);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _err = _extractError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _ModalSheet(
      isDark: isDark,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(
              icon: Icons.group_add_outlined,
              iconBg: AppColors.infoLight,
              title: 'Criar patota',
              subtitle: 'Você será o administrador',
              isDark: isDark,
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FieldLabel('Nome da patota', isDark: isDark),
                  const SizedBox(height: 6),
                  _AppInput(
                    controller: _nameCtrl,
                    hint: 'Ex: Patota dos Brabos',
                    enabled: !_loading,
                    isDark: isDark,
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_err != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _err!,
                      style: const TextStyle(
                        color: AppColors.prototypeDanger,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _PrimaryBtn(
                    label: 'Criar patota',
                    loading: _loading,
                    onTap: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _extractError(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message'] ?? data['error'] ?? data['title'];
      if (msg is String && msg.trim().isNotEmpty) return msg;
    }
    if (e.message != null && e.message!.trim().isNotEmpty) {
      return e.message!;
    }
  }
  return 'Ocorreu um erro. Tente novamente.';
}

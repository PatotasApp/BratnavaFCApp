import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../group_settings/presentation/providers/group_settings_provider.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';

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
  final String name;
  final int skillPoints;
  final bool isGoalkeeper;
  final bool isGuest;
  final int status;
  final int? guestStarRating;
  // mensalista ratings
  final int? attackRating;
  final int? defenseRating;
  final int? overallRating;   // displayed as "Físico"

  const _PlayerDto({
    required this.id,
    this.userId,
    this.userName,
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
        name: j['name'] as String? ?? '',
        skillPoints: j['skillPoints'] as int? ?? 0,
        isGoalkeeper: j['isGoalkeeper'] as bool? ?? false,
        isGuest: j['isGuest'] as bool? ?? false,
        status: j['status'] as int? ?? 1,
        guestStarRating: j['guestStarRating'] as int?,
        attackRating:  j['attackRating']  as int?,
        defenseRating: j['defenseRating'] as int?,
        overallRating: j['overallRating'] as int?,
      );
}

class _GroupDto {
  final String id;
  final String name;
  final List<String> adminIds;
  final List<_PlayerDto> players;
  final String createdByUserId;

  const _GroupDto({
    required this.id,
    required this.name,
    required this.adminIds,
    required this.players,
    required this.createdByUserId,
  });

  factory _GroupDto.fromJson(Map<String, dynamic> j) => _GroupDto(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        adminIds: List<String>.from(j['adminIds'] as List? ?? const []),
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

  _MyPlayerItem? get _myPlayerInExpanded =>
      _expandedGroupId == null
          ? null
          : _myPlayers.where((p) => p.groupId == _expandedGroupId).firstOrNull;

  String get _activePlayerId => _myPlayerInExpanded?.playerId ?? '';

  bool _isGroupAdmin(String groupId) {
    final account = ref.read(accountStoreProvider).activeAccount;
    if (account == null) return false;
    return account.isGroupAdmin(groupId);
  }

  bool _isGroupFinanceiro(String groupId) {
    final account = ref.read(accountStoreProvider).activeAccount;
    if (account == null) return false;
    return account.isGroupFinanceiro(groupId);
  }

  Future<void> _loadPaymentData(String groupId) async {
    // Only financeiros/admins see payment badges
    if (!_isGroupFinanceiro(groupId)) {
      if (mounted) setState(() => _paymentMap = {});
      return;
    }

    final year = DateTime.now().year;
    final currentMonth = DateTime.now().month;

    try {
      final results = await Future.wait([
        _dio.get(ApiConstants.monthlyGrid(groupId, year)),
        _dio.get(ApiConstants.extraCharges(groupId)),
      ]);

      final gridRaw   = _unwrap(results[0].data);
      final extrasRaw = _unwrap(results[1].data) as List? ?? [];
      final grid      = gridRaw is Map<String, dynamic> ? gridRaw : <String, dynamic>{};

      final hasMonthlyFee = (grid['monthlyFee'] as num? ?? 0) > 0;
      final map = <String, _PaymentBadge>{};

      // ── monthly grid rows ──
      for (final row in (grid['players'] as List? ?? [])) {
        final r = row as Map<String, dynamic>;
        final playerId   = r['playerId'] as String? ?? '';
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
            map[pid] = (pendingMonths: existing.pendingMonths, pendingExtras: existing.pendingExtras + 1);
          } else {
            map[pid] = (pendingMonths: 0, pendingExtras: 1);
          }
        }
      }

      if (mounted) setState(() => _paymentMap = map);
    } catch (_) {
      // silencioso — badges simplesmente não aparecem
      if (mounted) setState(() => _paymentMap = {});
    }
  }

  List<_PlayerDto> get _activePlayers =>
      _group?.players.where((p) => p.status == 1 && !p.isGuest).toList() ?? [];

  List<_PlayerDto> get _guestPlayers =>
      _group?.players.where((p) => p.status == 1 && p.isGuest).toList() ?? [];

  List<_PlayerDto> get _inactivePlayers {
    final account = ref.read(accountStoreProvider).activeAccount;
    if (account == null) return [];
    final isAdminHere = account.isAdmin ||
        (_expandedGroupId != null && account.isGroupAdmin(_expandedGroupId!));
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
      final raw = _unwrap(res.data);
      setState(() {
        _myPlayers = (raw as List? ?? const [])
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
      final raw = _unwrap(res.data);
      final playerGroupIds = _myPlayers.map((p) => p.groupId).toSet();
      if (mounted) {
        setState(() {
          _adminOnlyGroups = (raw as List? ?? [])
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
    });

    try {
      final res = await _dio.get(ApiConstants.groupById(groupId));
      final raw = _unwrap(res.data);
      setState(() => _group = _GroupDto.fromJson(raw as Map<String, dynamic>));
      // Load payment badges in parallel (silently)
      _loadPaymentData(groupId);
    } catch (e) {
      setState(() {
        _groupError = extractDioError(e, 'Não foi possível carregar os dados da patota.');
      });
    } finally {
      if (mounted) setState(() => _groupLoading = false);
    }
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
      backgroundColor: Colors.transparent,
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
          await ref.read(authNotifierProvider.notifier).refreshGroupMembership();
          ref.invalidate(myPlayersProvider);
          // Abre automaticamente se agora há exatamente uma patota
          if (_myGroups.length == 1) {
            _openGroup(_myGroups.first['groupId']!);
          }
        },
      ),
    );
  }

  void _showAddGuest(String groupId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddGuestSheet(
        onSubmit: (name, isGoalkeeper, starRating) async {
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
        },
      ),
    );
  }

  void _showInvite(String groupId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteSheet(
        dio: _dio,
        groupId: groupId,
        existingUserIds: _existingUserIds,
        guestPlayers: _guestPlayers,
        onInvited: () async => _reloadGroup(),
      ),
    );
  }

  void _showEditPlayer(_PlayerDto player) {
    final isAdminHere =
        _expandedGroupId != null ? _isGroupAdmin(_expandedGroupId!) : false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditPlayerSheet(
        player: player,
        isAdmin: isAdminHere,
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
    // Garante rebuild quando activeGroupId muda (troca de patota na topbar)
    ref.watch(accountStoreProvider);

    return SingleChildScrollView(
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
          if (!_mineLoading && _myGroups.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildNewGroupFooter(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildNewGroupFooter(bool isDark) {
    return GestureDetector(
      onTap: _showCreateGroup,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add,
              size: 18,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Text(
              'Criar nova patota',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
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
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
          ),
          SizedBox(width: 12),
          Text(
            'Carregando patotas...',
            style: TextStyle(fontSize: 14, color: Colors.white70),
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
          const Icon(Icons.group_outlined, size: 36, color: Colors.white38),
          const SizedBox(height: 12),
          const Text(
            'Você não faz parte de nenhuma patota.',
            style: TextStyle(fontSize: 14, color: Colors.white60),
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
    final icons = GroupIcons.from(ref.watch(groupSettingsProvider(groupId)).valueOrNull);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GradientCard(
          dotPattern: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _GroupAvatar(
                    letter: groupName.isEmpty ? 'G' : groupName.characters.first,
                    size: 48,
                    radius: 16,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          groupName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
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
                          style: const TextStyle(fontSize: 13, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  if (_groupLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
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
                  onLeave: _showLeaveConfirm,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.07),
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
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
                ? _isGroupFinanceiro(_expandedGroupId!)
                : false,
            paymentMap: _paymentMap,
            icons: icons,
            isDark: isDark,
            onEditPlayer: _showEditPlayer,
          ),
        ),
      ],
    );
  }

  Widget _buildAccordion(bool isDark) {
    final account = ref.watch(accountStoreProvider).activeAccount;
    final expandedIcons = _expandedGroupId != null
        ? GroupIcons.from(ref.watch(groupSettingsProvider(_expandedGroupId!)).valueOrNull)
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
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Icon(
                  Icons.group_outlined,
                  size: 22,
                  color: Colors.white,
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
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${_myGroups.length} patotas',
                      style: const TextStyle(fontSize: 13, color: Colors.white60),
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
                      isFinanceiroHere: _isGroupFinanceiro(groupId),
                      paymentMap: _paymentMap,
                      icons: expandedIcons,
                      isDark: isDark,
                      onEditPlayer: _showEditPlayer,
                    )
                  : null,
            ),
          );
        }),
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
  final VoidCallback onLeave;

  const _HeaderButtons({
    required this.isAdminHere,
    required this.isCreator,
    required this.myPlayer,
    required this.activePlayerId,
    required this.onAddGuest,
    required this.onInvite,
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
        if (isAdminHere) ...[
          _DarkBtn(
            label: 'Convidado',
            icon: Icons.add,
            style: _DarkBtnStyle.ghost,
            onTap: onAddGuest,
          ),
          _DarkBtn(
            label: 'Convidar',
            icon: Icons.person_add_alt_1_outlined,
            style: _DarkBtnStyle.solid,
            onTap: onInvite,
          ),
        ],
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
        bg = Colors.white.withValues(alpha: 0.10);
        borderColor = Colors.white.withValues(alpha: 0.20);
        textColor = Colors.white;
        break;
      case _DarkBtnStyle.solid:
        bg = Colors.white;
        borderColor = Colors.transparent;
        textColor = const Color(0xFF0F172A);
        break;
      case _DarkBtnStyle.danger:
        bg = const Color(0xFFEF4444).withValues(alpha: 0.20);
        borderColor = const Color(0xFFF87171).withValues(alpha: 0.35);
        textColor = const Color(0xFFFCA5A5);
        break;
    }

    return Material(
      color: Colors.transparent,
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
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    final showLeave =
        !isAdminHere && myPlayer != null && !myPlayer!.isGuest && isExpanded;
    final showCreatorLeave = isAdminHere && isCreator && isExpanded;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isExpanded && !isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
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
                        letter: groupName.isEmpty ? 'G' : groupName.characters.first,
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
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            if (isAdminHere)
                              Text(
                                'Você administra',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF94A3B8),
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
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
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
        ? (isDark ? Colors.white : const Color(0xFF0F172A))
        : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9));

    final fg = isExpanded
        ? (isDark ? const Color(0xFF0F172A) : Colors.white)
        : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569));

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
        bg = const Color(0xFF0F172A);
        textColor = Colors.white;
        borderColor = Colors.transparent;
        break;
      case _SmallBtnVariant.secondary:
        bg = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
        textColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
        borderColor = isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0);
        break;
      case _SmallBtnVariant.danger:
        bg = Colors.transparent;
        textColor = const Color(0xFFE11D48);
        borderColor = const Color(0xFFFDA4AF);
        break;
    }

    return Material(
      color: Colors.transparent,
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
  });

  @override
  State<_GroupContent> createState() => _GroupContentState();
}

class _GroupContentState extends State<_GroupContent> {
  int _tab = 0; // 0 = Jogadores, 1 = Avaliações

  @override
  Widget build(BuildContext context) {
    final group          = widget.group;
    final groupLoading   = widget.groupLoading;
    final groupError     = widget.groupError;
    final activePlayers  = widget.activePlayers;
    final guestPlayers   = widget.guestPlayers;
    final inactivePlayers= widget.inactivePlayers;
    final activePlayerId = widget.activePlayerId;
    final isAdminHere    = widget.isAdminHere;
    final isFinanceiroHere = widget.isFinanceiroHere;
    final paymentMap     = widget.paymentMap;
    final icons          = widget.icons;
    final isDark         = widget.isDark;
    final onEditPlayer   = widget.onEditPlayer;

    if (groupError != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 15, color: Color(0xFFBE123C)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                groupError,
                style: const TextStyle(fontSize: 13, color: Color(0xFFBE123C)),
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

    if (activePlayers.isEmpty && guestPlayers.isEmpty && inactivePlayers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.group_outlined,
              size: 32,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
            ),
            const SizedBox(height: 8),
            Text(
              'Nenhum jogador nesta patota.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
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
            tab:    _tab,
            isDark: isDark,
            onTab:  (t) => setState(() => _tab = t),
          ),
          const SizedBox(height: 16),
        ],

        // ── Tab content ──────────────────────────────────────────────
        if (_tab == 0 || !isAdminHere) ...[
          if (activePlayers.isEmpty)
            Text(
              'Nenhum mensalista ativo.',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            )
          else
            _PlayerSection(
              label: 'Mensalistas',
              count: activePlayers.length,
              iconData: Icons.check,
              badgeBg: const Color(0xFF10B981),
              badgeTextColor: const Color(0xFF065F46),
              badgeLabelBg: const Color(0xFFD1FAE5),
              players: activePlayers,
              activePlayerId: activePlayerId,
              isAdminHere: isAdminHere,
              isFinanceiroHere: isFinanceiroHere,
              paymentMap: paymentMap,
              icons: icons,
              dim: false,
              isDark: isDark,
              onEdit: onEditPlayer,
            ),
          if (guestPlayers.isNotEmpty) ...[
            const SizedBox(height: 20),
            _PlayerSection(
              label: 'Convidados',
              count: guestPlayers.length,
              iconData: Icons.person_add_alt_1_outlined,
              badgeBg: const Color(0xFFF59E0B),
              badgeTextColor: const Color(0xFF92400E),
              badgeLabelBg: const Color(0xFFFEF3C7),
              players: guestPlayers,
              activePlayerId: activePlayerId,
              isAdminHere: isAdminHere,
              isFinanceiroHere: isFinanceiroHere,
              paymentMap: paymentMap,
              icons: icons,
              dim: false,
              isDark: isDark,
              onEdit: onEditPlayer,
            ),
          ],
          if (inactivePlayers.isNotEmpty) ...[
            const SizedBox(height: 20),
            _PlayerSection(
              label: 'Inativos',
              count: inactivePlayers.length,
              iconData: Icons.close,
              badgeBg: const Color(0xFF94A3B8),
              badgeTextColor: isDark
                  ? const Color(0xFFCBD5E1)
                  : const Color(0xFF64748B),
              badgeLabelBg:
                  isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              players: inactivePlayers,
              activePlayerId: activePlayerId,
              isAdminHere: isAdminHere,
              isFinanceiroHere: isFinanceiroHere,
              paymentMap: paymentMap,
              icons: icons,
              dim: true,
              isDark: isDark,
              onEdit: onEditPlayer,
            ),
          ],
        ] else ...[
          _RatingsTab(
            players: [...activePlayers, ...guestPlayers],
            activePlayerId: activePlayerId,
            isAdminHere: isAdminHere,
            isDark: isDark,
            onEdit: onEditPlayer,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group Tab Bar
// ─────────────────────────────────────────────────────────────────────────────

class _GroupTabBar extends StatelessWidget {
  final int          tab;
  final bool         isDark;
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
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _GroupTab(
            label:  'Jogadores',
            icon:   Icons.group_outlined,
            active: tab == 0,
            isDark: isDark,
            onTap:  () => onTab(0),
          ),
          _GroupTab(
            label:  'Avaliações',
            icon:   Icons.star_rounded,
            active: tab == 1,
            isDark: isDark,
            onTap:  () => onTab(1),
          ),
        ],
      ),
    );
  }
}

class _GroupTab extends StatelessWidget {
  final String   label;
  final IconData icon;
  final bool     active;
  final bool     isDark;
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
                ? (isDark ? const Color(0xFF334155) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
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
                size:  15,
                color: active
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8)),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize:   13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : (isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8)),
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
  final List<_PlayerDto>          players;
  final String                    activePlayerId;
  final bool                      isAdminHere;
  final bool                      isDark;
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
  int _sortBy = 0;

  double? _sortValue(_PlayerDto p) {
    switch (_sortBy) {
      case 1:  return p.attackRating?.toDouble();
      case 2:  return p.defenseRating?.toDouble();
      case 3:  return p.overallRating?.toDouble();
      default: return p.computedOverall;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark      = widget.isDark;
    final mensalistas = widget.players.where((p) => !p.isGuest).toList();
    final guests      = widget.players.where((p) =>  p.isGuest).toList();

    mensalistas.sort((a, b) {
      final va = _sortValue(a);
      final vb = _sortValue(b);
      if (va == null && vb == null) return a.name.compareTo(b.name);
      if (va == null) return  1;
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
            Icon(Icons.bar_chart_rounded, size: 36,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
            const SizedBox(height: 8),
            Text('Nenhum jogador ainda.',
                style: TextStyle(fontSize: 14,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Sort filter bar ──────────────────────────────────────────
        if (mensalistas.isNotEmpty) ...[
          _RatingsSortBar(
            sortBy: _sortBy,
            isDark: isDark,
            onSort: (s) => setState(() => _sortBy = s),
          ),
          const SizedBox(height: 12),
        ],

        // ── Mensalistas ──────────────────────────────────────────────
        if (mensalistas.isNotEmpty) ...[
          _RatingSectionHeader(
            icon:      Icons.sports_soccer_rounded,
            iconColor: const Color(0xFF3B82F6),
            label:     'MENSALISTAS',
            count:     mensalistas.length,
            countBg:   isDark ? const Color(0xFF1E3A5F) : const Color(0xFFEFF6FF),
            countFg:   const Color(0xFF1D4ED8),
            isDark:    isDark,
          ),
          const SizedBox(height: 8),
          ...mensalistas.asMap().entries.map((e) => _RatingRow(
            rank:        e.key + 1,
            player:      e.value,
            sortBy:      _sortBy,
            isMe:        e.value.id == widget.activePlayerId,
            isAdminHere: widget.isAdminHere,
            isDark:      isDark,
            onEdit:      widget.onEdit,
          )),
        ],

        // ── Convidados ───────────────────────────────────────────────
        if (guests.isNotEmpty) ...[
          if (mensalistas.isNotEmpty) const SizedBox(height: 20),
          _RatingSectionHeader(
            icon:      Icons.star_rounded,
            iconColor: const Color(0xFFF59E0B),
            label:     'CONVIDADOS',
            count:     guests.length,
            countBg:   isDark ? const Color(0xFF3D2B00) : const Color(0xFFFEF3C7),
            countFg:   const Color(0xFF92400E),
            isDark:    isDark,
          ),
          const SizedBox(height: 8),
          ...guests.asMap().entries.map((e) => _StarRow(
            rank:        e.key + 1,
            player:      e.value,
            isMe:        e.value.id == widget.activePlayerId,
            isAdminHere: widget.isAdminHere,
            isDark:      isDark,
            onEdit:      widget.onEdit,
          )),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ratings Sort Bar
// ─────────────────────────────────────────────────────────────────────────────

class _RatingsSortBar extends StatelessWidget {
  final int  sortBy;
  final bool isDark;
  final void Function(int) onSort;

  const _RatingsSortBar({
    required this.sortBy,
    required this.isDark,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    const tabs = [
      ('⭐', 'Overall'),
      ('⚔️', 'Ataque'),
      ('🛡️', 'Defesa'),
      ('💪', 'Físico'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = sortBy == i;
          return Padding(
            padding: EdgeInsets.only(right: i < tabs.length - 1 ? 6 : 0),
            child: GestureDetector(
              onTap: () => onSort(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: active
                      ? (isDark ? const Color(0xFF334155) : const Color(0xFF0F172A))
                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: active
                        ? Colors.transparent
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tabs[i].$1, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      tabs[i].$2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? Colors.white
                            : (isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _RatingSectionHeader extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   label;
  final int      count;
  final Color    countBg;
  final Color    countFg;
  final bool     isDark;

  const _RatingSectionHeader({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.count,
    required this.countBg,
    required this.countFg,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20, height: 20,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 12, color: iconColor),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: countBg, borderRadius: BorderRadius.circular(100),
          ),
          child: Text('$count',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: countFg)),
        ),
      ],
    );
  }
}

// ── Row for mensalistas: shows attack / defense / physical ratings ─────────────

class _RatingRow extends StatelessWidget {
  final int            rank;
  final _PlayerDto     player;
  final int            sortBy;   // 0=Overall 1=Ataque 2=Defesa 3=Físico
  final bool           isMe;
  final bool           isAdminHere;
  final bool           isDark;
  final void Function(_PlayerDto) onEdit;

  const _RatingRow({
    required this.rank,
    required this.player,
    required this.sortBy,
    required this.isMe,
    required this.isAdminHere,
    required this.isDark,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final overall = player.computedOverall;
    final atk     = player.attackRating;
    final def     = player.defenseRating;
    final phys    = player.overallRating;
    final hasAny  = overall != null;

    Color rankBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    Color rankFg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    if (hasAny) {
      if (rank == 1)      { rankBg = const Color(0xFFFBBF24); rankFg = const Color(0xFF78350F); }
      else if (rank == 2) { rankBg = const Color(0xFFCBD5E1); rankFg = const Color(0xFF334155); }
      else if (rank == 3) { rankBg = const Color(0xFFFDBA74); rankFg = const Color(0xFF7C2D12); }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: isMe
            ? (isDark ? const Color(0xFF0C2A20) : const Color(0xFFECFDF5))
            : (isDark ? const Color(0xFF0F172A) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? const Color(0xFF6EE7B7)
              : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
          width: isMe ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: rankBg, borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: Text(
                  hasAny ? '$rank' : '—',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: rankFg),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (hasAny)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    overall.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                )
              else
                Text(
                  'Sem avaliação',
                  style: TextStyle(
                    fontSize: 11, fontStyle: FontStyle.italic,
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                  ),
                ),
              if (isAdminHere) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => onEdit(player),
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 24, height: 24,
                    child: Icon(Icons.edit_outlined, size: 13,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ],
          ),
          if (hasAny) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(width: 38), // indent under rank badge
                _RatingChip(
                  emoji: '⚔️', value: atk,
                  activeSort: sortBy == 1,
                  color: const Color(0xFFEF4444), isDark: isDark,
                ),
                const SizedBox(width: 6),
                _RatingChip(
                  emoji: '🛡️', value: def,
                  activeSort: sortBy == 2,
                  color: const Color(0xFF3B82F6), isDark: isDark,
                ),
                const SizedBox(width: 6),
                _RatingChip(
                  emoji: '💪', value: phys,
                  activeSort: sortBy == 3,
                  color: const Color(0xFFF59E0B), isDark: isDark,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  final String emoji;
  final int?   value;
  final bool   activeSort;
  final Color  color;
  final bool   isDark;

  const _RatingChip({
    required this.emoji,
    required this.value,
    required this.activeSort,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: activeSort
            ? color.withValues(alpha: 0.15)
            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: activeSort
              ? color.withValues(alpha: 0.35)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 3),
          Text(
            value != null ? '$value' : '—',
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: activeSort
                  ? color
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Row for guests: shows star rating ────────────────────────────────────────

class _StarRow extends StatelessWidget {
  final int            rank;
  final _PlayerDto     player;
  final bool           isMe;
  final bool           isAdminHere;
  final bool           isDark;
  final void Function(_PlayerDto) onEdit;

  const _StarRow({
    required this.rank,
    required this.player,
    required this.isMe,
    required this.isAdminHere,
    required this.isDark,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final rating    = player.guestStarRating;
    final hasRating = rating != null;

    Color rankBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    Color rankFg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    if (hasRating) {
      if (rank == 1) { rankBg = const Color(0xFFFBBF24); rankFg = const Color(0xFF78350F); }
      else if (rank == 2) { rankBg = const Color(0xFFCBD5E1); rankFg = const Color(0xFF334155); }
      else if (rank == 3) { rankBg = const Color(0xFFFDBA74); rankFg = const Color(0xFF7C2D12); }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? (isDark ? const Color(0xFF0C2A20) : const Color(0xFFECFDF5))
            : (isDark ? const Color(0xFF0F172A) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? const Color(0xFF6EE7B7)
              : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
          width: isMe ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: rankBg, borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: Text(hasRating ? '$rank' : '—',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: rankFg)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(player.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A))),
          ),
          const SizedBox(width: 8),
          if (hasRating)
            Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) => Text('★',
                style: TextStyle(fontSize: 14, color: i < rating
                    ? const Color(0xFFFBBF24)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))))))
          else
            Text('Sem avaliação', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic,
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))),
          if (isAdminHere) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () => onEdit(player),
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(width: 24, height: 24,
                  child: Icon(Icons.edit_outlined, size: 13,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerSection extends StatelessWidget {
  final String label;
  final int count;
  final IconData iconData;
  final Color badgeBg;
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

  const _PlayerSection({
    required this.label,
    required this.count,
    required this.iconData,
    required this.badgeBg,
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
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(iconData, size: 11, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeLabelBg,
                    borderRadius: BorderRadius.circular(100),
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
  final _PaymentBadge? pmt;   // null = not a financeiro or no data
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
    this.icons = GroupIcons.defaults,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = player.id == activePlayerId;
    final canEdit = isAdminHere || isMe;

    final parts = player.name.trim().split(RegExp(r'\s+'));
    final initials = parts.take(2).map((w) => w[0]).join().toUpperCase();

    Color avatarBg;
    Color avatarFg;

    if (isMe) {
      avatarBg = const Color(0xFF059669);
      avatarFg = Colors.white;
    } else if (player.isGuest) {
      avatarBg = const Color(0xFFFEF3C7);
      avatarFg = const Color(0xFFD97706);
    } else {
      avatarBg = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
      avatarFg = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    }

    final borderColor = isMe
        ? const Color(0xFF6EE7B7)
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFE2E8F0));

    return Opacity(
      opacity: dim ? 0.5 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isMe ? 1.5 : 1),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
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
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: avatarBg,
                    shape: BoxShape.circle,
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
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              player.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          renderGroupIcon(
                            player.isGoalkeeper ? icons.goalkeeper : icons.player,
                            size: 13,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                      if (player.userName != null && player.userName!.isNotEmpty)
                        Text(
                          '@${player.userName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
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
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Text(
                          'Você',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
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
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            // ── star rating (guest + admin) ──
            if (player.isGuest &&
                player.guestStarRating != null &&
                isAdminHere) ...[
              const SizedBox(height: 8),
              _StarDisplay(value: player.guestStarRating!),
            ],
            // ── payment badge (financeiro only) ──
            if (pmt != null) ...[
              const SizedBox(height: 8),
              _PaymentBadgeWidget(pmt: pmt!),
            ],
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
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 11, color: Color(0xFF10B981)),
            SizedBox(width: 4),
            Text(
              'Em dia',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF065F46),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 11, color: Color(0xFFBE123C)),
          const SizedBox(width: 4),
          Text(
            '$total pendência${total != 1 ? 's' : ''}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFFBE123C),
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
            color:
                i < value ? const Color(0xFFFBBF24) : const Color(0xFFE2E8F0),
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
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
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
      ..color = Colors.white.withValues(alpha: 0.06)
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
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      alignment: Alignment.center,
      child: Text(
        letter.toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.35,
          fontWeight: FontWeight.w900,
          color: Colors.white,
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
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.15),
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
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
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
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
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
        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF374151),
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
        color: isDark ? Colors.white : const Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB)),
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
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
                      selected ? const Color(0xFFFBBF24) : const Color(0xFFCBD5E1),
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

class _RatingSlider extends StatelessWidget {
  final String   label;
  final String   icon;
  final Color    color;
  final int?     value;
  final bool     disabled;
  final bool     isDark;
  final ValueChanged<int> onChanged;

  const _RatingSlider({
    required this.label,
    required this.icon,
    required this.color,
    required this.value,
    required this.disabled,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = value ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF374151),
              ),
            ),
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 120),
              child: Container(
                key: ValueKey(displayValue),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: value != null
                      ? color.withValues(alpha: 0.12)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  value != null ? '$displayValue' : '—',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: value != null
                        ? color
                        : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  ),
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor:   color,
            inactiveTrackColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            thumbColor:         color,
            overlayColor:       color.withValues(alpha: 0.12),
            trackHeight:        4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: displayValue.toDouble(),
            min:   0,
            max:   10,
            divisions: 10,
            onChanged: disabled ? null : (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Guest
// ─────────────────────────────────────────────────────────────────────────────

class _AddGuestSheet extends StatefulWidget {
  final Future<void> Function(String name, bool isGoalkeeper, int? starRating)
      onSubmit;

  const _AddGuestSheet({required this.onSubmit});

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

    return _ModalSheet(
      isDark: isDark,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(
              icon: Icons.add,
              iconBg: const Color(0xFFF59E0B),
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
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFF374151),
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
                        color: Color(0xFFEF4444),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Player
// ─────────────────────────────────────────────────────────────────────────────

class _EditPlayerSheet extends StatefulWidget {
  final _PlayerDto player;
  final bool isAdmin;
  final Future<void> Function(Map<String, dynamic>) onSaved;
  /// Called when admin confirms removing the player from the group. Null = feature not available.
  final Future<void> Function()? onRemove;

  const _EditPlayerSheet({
    required this.player,
    required this.isAdmin,
    required this.onSaved,
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
  bool _loading  = false;
  bool _removing = false;
  bool _confirmRemove = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _nameCtrl      = TextEditingController(text: widget.player.name);
    _isGuest       = widget.player.isGuest;
    _isActive      = widget.player.status == 1;
    _isGoalkeeper  = widget.player.isGoalkeeper;
    _attackRating  = widget.player.attackRating;
    _defenseRating = widget.player.defenseRating;
    _overallRating = widget.player.overallRating;
    _starRating    = widget.player.guestStarRating;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _remove() async {
    setState(() { _removing = true; _err = null; });
    try {
      await widget.onRemove!();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _err = _extractError(e); _confirmRemove = false; });
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
        dto['status']  = _isActive ? 1 : 2;
        dto['isGuest'] = _isGuest;
        if (_isGuest) {
          if (_starRating != null) dto['guestStarRating'] = _starRating;
        } else {
          if (_attackRating  != null) dto['attackRating']  = _attackRating;
          if (_defenseRating != null) dto['defenseRating'] = _defenseRating;
          if (_overallRating != null) dto['overallRating'] = _overallRating;
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

    return _ModalSheet(
      isDark: isDark,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(
              icon: Icons.edit_outlined,
              iconBg: isDark ? Colors.white : const Color(0xFF0F172A),
              iconColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              title: 'Editar jogador',
              subtitle: widget.player.name,
              isDark: isDark,
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                  if (widget.isAdmin) ...[
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
                                ? const Color(0xFFE2E8F0)
                                : const Color(0xFF374151),
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
                                ? const Color(0xFFE2E8F0)
                                : const Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                    // Avaliação: ratings para mensalistas, estrelas para convidados
                    if (!_isGuest) ...[
                      const SizedBox(height: 16),
                      _FieldLabel('Avaliações (1–10)', isDark: isDark),
                      const SizedBox(height: 4),
                      Text(
                        'Defina o nível do jogador em cada categoria',
                        style: TextStyle(fontSize: 11,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 12),
                      _RatingSlider(
                        label:    'Ataque',
                        icon:     '⚔️',
                        color:    const Color(0xFFEF4444),
                        value:    _attackRating,
                        disabled: _loading,
                        isDark:   isDark,
                        onChanged: (v) => setState(() => _attackRating = v),
                      ),
                      const SizedBox(height: 8),
                      _RatingSlider(
                        label:    'Defesa',
                        icon:     '🛡️',
                        color:    const Color(0xFF3B82F6),
                        value:    _defenseRating,
                        disabled: _loading,
                        isDark:   isDark,
                        onChanged: (v) => setState(() => _defenseRating = v),
                      ),
                      const SizedBox(height: 8),
                      _RatingSlider(
                        label:    'Físico',
                        icon:     '💪',
                        color:    const Color(0xFFF59E0B),
                        value:    _overallRating,
                        disabled: _loading,
                        isDark:   isDark,
                        onChanged: (v) => setState(() => _overallRating = v),
                      ),
                    ] else ...[
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
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _PrimaryBtn(
                    label: _loading ? 'Salvando...' : 'Salvar',
                    loading: _loading || _removing,
                    onTap: _save,
                  ),

                  // ── Remover da patota (admin + não-guest + tem userId) ──
                  if (widget.onRemove != null) ...[
                    const SizedBox(height: 10),
                    if (!_confirmRemove)
                      SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: (_loading || _removing)
                              ? null
                              : () => setState(() => _confirmRemove = true),
                          icon: const Icon(Icons.person_remove_outlined, size: 15),
                          label: const Text('Remover da patota'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFE11D48),
                            side: const BorderSide(color: Color(0xFFFDA4AF)),
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
                              ? const Color(0xFF2D0A14)
                              : const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF9F1239)
                                : const Color(0xFFFECACA),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    size: 14, color: Color(0xFFE11D48)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${widget.player.name} voltará a ser convidado '
                                    'e perderá o vínculo com a conta. '
                                    'O histórico de partidas é preservado.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFBE123C),
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
                                      : () => setState(() => _confirmRemove = false),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    side: BorderSide(
                                        color: isDark
                                            ? const Color(0xFF475569)
                                            : const Color(0xFFCBD5E1)),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: Text(
                                    'Cancelar',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
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
                                              strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.person_remove_outlined,
                                          size: 13),
                                  label: Text(_removing ? 'Removendo...' : 'Confirmar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE11D48),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
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
        inviteId: j['id']                 as String? ?? '',
        userId:   j['targetUserId']       as String? ?? '',
        fullName: j['targetUserFullName'] as String? ?? '',
        userName: j['targetUserLogin']    as String? ?? '',
      );
}

class _InviteSheet extends StatefulWidget {
  final Dio dio;
  final String groupId;
  final Set<String> existingUserIds;
  final List<_PlayerDto> guestPlayers;
  final Future<void> Function() onInvited;

  const _InviteSheet({
    required this.dio,
    required this.groupId,
    required this.existingUserIds,
    required this.guestPlayers,
    required this.onInvited,
  });

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _loading        = false;
  bool _pendingLoading = false;
  bool _hasTried       = false;
  String? _err;
  List<_UserResult>        _results      = [];
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
      final res  = await widget.dio.get(ApiConstants.groupPendingInvites(widget.groupId));
      final raw  = _GroupsPageState._unwrap(res.data);
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
    final messenger   = ScaffoldMessenger.of(context);
    final displayName = user.fullName.isNotEmpty ? user.fullName : user.userName;

    // If there are unlinked guests, ask whether to associate this user with one.
    String? guestPlayerId;
    if (widget.guestPlayers.isNotEmpty && mounted) {
      final picked = await showDialog<_PlayerDto?>(
        context: context,
        builder: (_) => _LinkGuestDialog(
          userName: user.fullName.isNotEmpty ? user.fullName : user.userName,
          guests:   widget.guestPlayers,
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
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      final errMsg    = _extractError(e);
      final isPending = errMsg.toLowerCase().contains('pendente');
      if (isPending) await _loadPendingInvites();
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(errMsg),
          backgroundColor: isPending
              ? const Color(0xFFF59E0B)
              : const Color(0xFFE11D48),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelInvite(_PendingInviteItem item) async {
    final messenger   = ScaffoldMessenger.of(context);
    final displayName = item.fullName.isNotEmpty ? item.fullName : item.userName;
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
    } catch (e) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(_extractError(e)),
          backgroundColor: const Color(0xFFE11D48),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              icon:     Icons.person_add_alt_1_outlined,
              iconBg:   const Color(0xFF0F172A),
              title:    'Convidar jogador',
              subtitle: 'Busque por nome, usuário ou email',
              isDark:   isDark,
            ),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_pendingItems.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              labelColor: isDark ? Colors.white : const Color(0xFF0F172A),
              unselectedLabelColor:
                  isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              indicatorColor: const Color(0xFF0F172A),
              dividerColor:
                  isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            Flexible(
              child: TabBarView(
                children: [
                  _buildSearchTab(isDark),
                  _buildPendingTab(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _AppInput(
            controller: _searchCtrl,
            hint:    'Pesquisar...',
            enabled: !_loading,
            isDark:  isDark,
          ),
          if (_err != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_err!,
                  style: const TextStyle(color: Color(0xFFEF4444))),
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
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
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
                          final user     = _results[index];
                          final name     = user.fullName.isEmpty
                              ? user.userName : user.fullName;
                          final isMember = widget.existingUserIds.contains(user.id);
                          final isPending = _pendingUserIds.contains(user.id);
                          return _buildUserRow(
                            isDark:   isDark,
                            name:     name,
                            userName: user.userName,
                            trailing: isMember
                                ? _StatusBadge(label: 'Membro', isDark: isDark)
                                : isPending
                                    ? _StatusBadge(
                                        label: 'Pendente',
                                        isDark: isDark,
                                        color: const Color(0xFFF59E0B),
                                      )
                                    : ElevatedButton(
                                        onPressed:
                                            _loading ? null : () => _invite(user),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF0F172A),
                                          foregroundColor: Colors.white,
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
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF64748B),
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
          isDark:   isDark,
          name:     name,
          userName: item.userName,
          trailing: TextButton.icon(
            onPressed: () => _cancelInvite(item),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            icon:  const Icon(Icons.close, size: 16),
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
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor:
                isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '@$userName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
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
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0));
    final fg = color ??
        (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569));

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
  final String            userName;
  final List<_PlayerDto>  guests;

  /// Sentinel returned when the user chooses "Não vincular".
  static const _PlayerDto sentinel = _PlayerDto(
    id: '__no_link__', name: '', skillPoints: 0,
    isGoalkeeper: false, isGuest: true, status: 0,
  );

  const _LinkGuestDialog({
    required this.userName,
    required this.guests,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);

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
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.link_rounded,
                      size: 18, color: Color(0xFFF59E0B)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vincular a convidado?',
                        style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        userName,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
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
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
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
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
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
                                color: Color(0xFFD97706),
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
                                fontSize: 14, fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (g.isGoalkeeper) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.shield_outlined, size: 13,
                                color: isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8)),
                          ],
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right_rounded, size: 18,
                              color: isDark
                                  ? const Color(0xFF475569)
                                  : const Color(0xFFCBD5E1)),
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
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, sentinel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
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
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      title: Text(
        'Sair da patota?',
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
      content: Text(
        'Essa ação remove você da patota atual.',
        style: TextStyle(
          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
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
            backgroundColor: const Color(0xFFE11D48),
            foregroundColor: Colors.white,
          ),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
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
              iconBg: const Color(0xFF6366F1),
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
                        color: Color(0xFFF87171),
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
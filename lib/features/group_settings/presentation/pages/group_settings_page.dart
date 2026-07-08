import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/account.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../data/datasources/group_settings_remote_datasource.dart';
import '../../domain/entities/group_settings.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/group_settings_provider.dart';

// ── Icon types ────────────────────────────────────────────────────────────────

class _IconOpt {
  final String value; // "⚽" | "lucide:Trophy" | "letter:G"
  final String label;
  const _IconOpt(this.value, this.label);
}

class _IconCat {
  final String        key;          // matches API field name
  final String        label;        // display name
  final String        defaultValue; // fallback when null
  final List<_IconOpt> options;
  const _IconCat({
    required this.key,
    required this.label,
    required this.defaultValue,
    required this.options,
  });
}

// Exact options from site's groupIcons.ts
const _kIconCats = <_IconCat>[
  _IconCat(
    key: 'goalIcon', label: 'Gol', defaultValue: '⚽',
    options: [
      _IconOpt('⚽',            'Bola de futebol'),
      _IconOpt('🥅',            'Trave / goleira'),
      _IconOpt('🎯',            'Alvo'),
      _IconOpt('lucide:Target', 'Mira'),
      _IconOpt('lucide:Medal',  'Medalha'),
      _IconOpt('letter:G',      'Letra G'),
    ],
  ),
  _IconCat(
    key: 'goalkeeperIcon', label: 'Goleiro', defaultValue: '🧤',
    options: [
      _IconOpt('🧤',                'Luvas de goleiro'),
      _IconOpt('🥅',                'Trave / goleira'),
      _IconOpt('🛡️',               'Escudo'),
      _IconOpt('🤲',                'Mãos abertas'),
      _IconOpt('lucide:ShieldAlert', 'Escudo alerta'),
      _IconOpt('lucide:Radar',       'Radar'),
      _IconOpt('letter:GL',          'Texto GL'),
    ],
  ),
  _IconCat(
    key: 'assistIcon', label: 'Assistência', defaultValue: '🤝',
    options: [
      _IconOpt('🤝',               'Aperto de mão'),
      _IconOpt('🎁',               'Presente'),
      _IconOpt('🪄',               'Varinha mágica'),
      _IconOpt('🔗',               'Corrente / link'),
      _IconOpt('🧠',               'Inteligência'),
      _IconOpt('lucide:Link',      'Corrente'),
      _IconOpt('lucide:Handshake', 'Handshake'),
      _IconOpt('letter:A',         'Letra A'),
      _IconOpt('letter:ASS',       'Texto ASS'),
    ],
  ),
  _IconCat(
    key: 'ownGoalIcon', label: 'Gol contra', defaultValue: '🚩',
    options: [
      _IconOpt('🚩',                   'Bandeira vermelha'),
      _IconOpt('😅',                   'Constrangido'),
      _IconOpt('💀',                   'Caveira'),
      _IconOpt('🤦',                   'Facepalm'),
      _IconOpt('❌',                   'X vermelho'),
      _IconOpt('⚠️',                   'Atenção'),
      _IconOpt('lucide:AlertTriangle', 'Triângulo alerta'),
      _IconOpt('lucide:Ban',           'Banido'),
      _IconOpt('letter:GC',            'Texto GC'),
      _IconOpt('letter:OG',            'Texto OG'),
    ],
  ),
  _IconCat(
    key: 'mvpIcon', label: 'MVP', defaultValue: 'lucide:Trophy',
    options: [
      _IconOpt('🏆',          'Troféu'),
      _IconOpt('⭐',          'Estrela'),
      _IconOpt('🌟',          'Estrela brilhando'),
      _IconOpt('🥇',          'Medalha de ouro'),
      _IconOpt('👑',          'Coroa'),
      _IconOpt('lucide:Trophy', 'Troféu (Trophy)'),
      _IconOpt('lucide:Award',  'Premiação (Award)'),
      _IconOpt('lucide:Medal',  'Medalha (Medal)'),
      _IconOpt('lucide:Crown',  'Coroa (Crown)'),
      _IconOpt('letter:MVP',   'Texto MVP'),
      _IconOpt('letter:M',     'Letra M'),
    ],
  ),
  _IconCat(
    key: 'playerIcon', label: 'Jogador', defaultValue: 'lucide:User',
    options: [
      _IconOpt('🏃',              'Correndo'),
      _IconOpt('👤',              'Silhueta'),
      _IconOpt('👟',              'Tênis / chuteira'),
      _IconOpt('🎽',              'Uniforme'),
      _IconOpt('lucide:User',      'Pessoa (User)'),
      _IconOpt('lucide:UserRound', 'Pessoa redonda'),
      _IconOpt('lucide:Shirt',     'Camisa'),
      _IconOpt('letter:J',         'Letra J'),
      _IconOpt('letter:P',         'Letra P'),
    ],
  ),
  _IconCat(
    key: 'rank1Icon', label: '1º Lugar', defaultValue: '🥇',
    options: [
      _IconOpt('🥇',             'Medalha de ouro'),
      _IconOpt('🏆',             'Troféu'),
      _IconOpt('👑',             'Coroa'),
      _IconOpt('⭐',             'Estrela'),
      _IconOpt('🌟',             'Estrela brilhando'),
      _IconOpt('1️⃣',            'Número 1'),
      _IconOpt('lucide:Medal',   'Medalha'),
      _IconOpt('lucide:Trophy',  'Troféu'),
      _IconOpt('lucide:Award',   'Premiação'),
      _IconOpt('letter:1',       'Dígito 1'),
    ],
  ),
  _IconCat(
    key: 'rank2Icon', label: '2º Lugar', defaultValue: '🥈',
    options: [
      _IconOpt('🥈',             'Medalha de prata'),
      _IconOpt('🎖️',            'Medalha militar'),
      _IconOpt('⭐',             'Estrela'),
      _IconOpt('2️⃣',            'Número 2'),
      _IconOpt('lucide:Medal',   'Medalha'),
      _IconOpt('lucide:Award',   'Premiação'),
      _IconOpt('letter:2',       'Dígito 2'),
    ],
  ),
  _IconCat(
    key: 'rank3Icon', label: '3º Lugar', defaultValue: '🥉',
    options: [
      _IconOpt('🥉',             'Medalha de bronze'),
      _IconOpt('🎖️',            'Medalha militar'),
      _IconOpt('⭐',             'Estrela'),
      _IconOpt('3️⃣',            'Número 3'),
      _IconOpt('lucide:Medal',   'Medalha'),
      _IconOpt('lucide:Award',   'Premiação'),
      _IconOpt('letter:3',       'Dígito 3'),
    ],
  ),
];

// ── Lucide → Material icon map ────────────────────────────────────────────────

const _kLucideMap = <String, IconData>{
  'Trophy':        Icons.emoji_events_outlined,
  'User':          Icons.person_outline,
  'Target':        Icons.gps_fixed,
  'Medal':         Icons.military_tech_outlined,
  'ShieldAlert':   Icons.shield_outlined,
  'Radar':         Icons.radar,
  'Link':          Icons.link_outlined,
  'Handshake':     Icons.handshake_outlined,
  'AlertTriangle': Icons.warning_amber_outlined,
  'Ban':           Icons.block_outlined,
  'Award':         Icons.workspace_premium_outlined,
  'Crown':         Icons.workspace_premium_outlined,
  'UserRound':     Icons.account_circle_outlined,
  'Shirt':         Icons.dry_cleaning_outlined,
};

// ── Day options (mirrors site's DAY_OPTIONS) ──────────────────────────────────

const _kDayLabels = <String>[
  'Sem padrão',
  'Domingo', 'Segunda-feira', 'Terça-feira', 'Quarta-feira',
  'Quinta-feira', 'Sexta-feira', 'Sábado',
];

// ── Page ──────────────────────────────────────────────────────────────────────

class GroupSettingsPage extends ConsumerStatefulWidget {
  const GroupSettingsPage({super.key});

  @override
  ConsumerState<GroupSettingsPage> createState() => _GroupSettingsPageWrapperState();
}

class _GroupSettingsPageWrapperState extends ConsumerState<GroupSettingsPage> {
  bool _refreshingRoles = true;

  @override
  void initState() {
    super.initState();
    // Atualiza as permissões antes de verificar o acesso, para que admins
    // recém-promovidos não vejam "Sem acesso" com dados desatualizados.
    Future.microtask(() async {
      await ref.read(authNotifierProvider.notifier).refreshRoles();
      if (mounted) setState(() => _refreshingRoles = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final account      = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    final groupId      = account?.activeGroupId ?? activePlayer?.groupId;

    if (groupId == null || groupId.isEmpty) {
      return const Scaffold(body: _NoGroupState(message: 'Crie ou entre em um grupo'));
    }

    // Enquanto atualiza as roles, exibe loading para não bloquear admins
    // recém-promovidos com "Sem acesso" antes das permissões serem carregadas.
    if (_refreshingRoles) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isGroupAdm = account!.isGroupAdmin(groupId);
    if (!isGroupAdm) {
      return const Scaffold(body: _NoGroupState(message: 'Verifique suas permissões'));
    }

    final settingsAsync = ref.watch(groupSettingsProvider(groupId));
    final detailAsync   = ref.watch(groupDetailProvider(groupId));

    return settingsAsync.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: _ErrorState(
          message: extractDioError(e, 'Não foi possível carregar as configurações.'),
          onRetry: () => ref.invalidate(groupSettingsProvider(groupId)),
        ),
      ),
      data: (settings) => _SettingsBody(
        settings:     settings,
        detailAsync:  detailAsync,
        groupId:      groupId,
        account:      account,
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _SettingsBody extends ConsumerStatefulWidget {
  final GroupSettings                   settings;
  final AsyncValue<GroupDetail>         detailAsync;
  final String                          groupId;
  final Account                         account;

  const _SettingsBody({
    required this.settings,
    required this.detailAsync,
    required this.groupId,
    required this.account,
  });

  @override
  ConsumerState<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends ConsumerState<_SettingsBody> {

  // ── Form state ────────────────────────────────────────────────────────────
  late final TextEditingController _placeCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  late final TextEditingController _feeCtrl;
  late final TextEditingController _goalkeeperFeeCtrl;

  late int?    _dayOfWeek;    // null = "Sem padrão"
  late String? _kickoffTime;  // "HH:mm" for display; saved as "HH:mm:ss"
  late int     _paymentMode;

  // ── Icon state ────────────────────────────────────────────────────────────
  late Map<String, String?> _icons;

  // ── MVP tie rule ──────────────────────────────────────────────────────────
  // 0 = Nenhum recebe MVP · 1 = Todos recebem MVP · 2 = Todos até um máximo
  late int _mvpTieRule;
  late int _mvpTieMaxPlayers;
  late final TextEditingController _mvpMaxCtrl;

  // ── Show player stats toggle ──────────────────────────────────────────────
  bool _showPlayerStats = false;

  // ── Notificações configuráveis ────────────────────────────────────────────
  int? _paymentDueDay;        // null = sem lembrete
  int? _autoFinalizeMvpHours; // null = desativado
  late final TextEditingController _autoFinalizeCtrl;

  // ── Tab state ─────────────────────────────────────────────────────────────
  int _activeTab = 0;

  // ── Save state ────────────────────────────────────────────────────────────
  bool    _saving     = false;
  bool    _isPersisted = false;
  String? _saveMsg;
  bool    _saveMsgOk  = false;

  @override
  void initState() {
    super.initState();
    _initFromSettings(widget.settings);
  }

  void _initFromSettings(GroupSettings s) {
    _placeCtrl = TextEditingController(text: s.defaultPlaceName ?? '');
    _minCtrl   = TextEditingController(text: s.minPlayers.toString());
    _maxCtrl   = TextEditingController(text: s.maxPlayers.toString());
    _feeCtrl            = TextEditingController(
      text: s.monthlyFee != null ? s.monthlyFee!.toStringAsFixed(2) : '',
    );
    _goalkeeperFeeCtrl  = TextEditingController(
      text: s.goalkeeperMonthlyFee != null ? s.goalkeeperMonthlyFee!.toStringAsFixed(2) : '',
    );
    _dayOfWeek    = s.defaultDayOfWeek;
    // API stores "HH:mm:ss" — display only "HH:mm"
    _kickoffTime  = s.defaultKickoffTime?.substring(0, 5.clamp(0, s.defaultKickoffTime!.length));
    _paymentMode  = s.paymentMode;
    _isPersisted  = s.isPersisted;
    _icons = {
      'goalIcon':       s.goalIcon,
      'goalkeeperIcon': s.goalkeeperIcon,
      'assistIcon':     s.assistIcon,
      'ownGoalIcon':    s.ownGoalIcon,
      'mvpIcon':        s.mvpIcon,
      'playerIcon':     s.playerIcon,
      'rank1Icon':      s.rank1Icon,
      'rank2Icon':      s.rank2Icon,
      'rank3Icon':      s.rank3Icon,
    };
    _mvpTieRule           = s.mvpTieRule;
    _mvpTieMaxPlayers     = s.mvpTieMaxPlayers;
    _mvpMaxCtrl           = TextEditingController(text: s.mvpTieMaxPlayers.toString());
    _showPlayerStats      = s.showPlayerStats;
    _paymentDueDay        = s.paymentDueDay;
    _autoFinalizeMvpHours = s.autoFinalizeMvpHours;
    _autoFinalizeCtrl     = TextEditingController(
      text: s.autoFinalizeMvpHours != null ? s.autoFinalizeMvpHours.toString() : '',
    );
  }

  @override
  void dispose() {
    _placeCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _feeCtrl.dispose();
    _goalkeeperFeeCtrl.dispose();
    _mvpMaxCtrl.dispose();
    _autoFinalizeCtrl.dispose();
    super.dispose();
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() { _saving = true; _saveMsg = null; });
    try {
      final ds  = ref.read(groupSettingsDsProvider);
      final min = int.tryParse(_minCtrl.text) ?? 5;
      final max = int.tryParse(_maxCtrl.text) ?? 6;

      // "HH:mm" → "HH:mm:ss" (mirrors site: `${defaultKickoffTime}:00`)
      final kickoff = _kickoffTime != null && _kickoffTime!.isNotEmpty
          ? '${_kickoffTime!}:00'
          : null;

      final place = _placeCtrl.text.trim().isEmpty
          ? null
          : _placeCtrl.text.trim();

      final fee = (_paymentMode == 0 && _feeCtrl.text.isNotEmpty)
          ? double.tryParse(_feeCtrl.text.replaceAll(',', '.'))
          : null;

      final goalkeeperFee = (_paymentMode == 0 && _goalkeeperFeeCtrl.text.isNotEmpty)
          ? double.tryParse(_goalkeeperFeeCtrl.text.replaceAll(',', '.'))
          : null;

      await ds.updateGroupSettings(
        widget.groupId,
        minPlayers:          min,
        maxPlayers:          max,
        defaultPlaceName:    place,
        defaultDayOfWeek:    _dayOfWeek,
        defaultKickoffTime:  kickoff,
        paymentMode:         _paymentMode,
        monthlyFee:          fee,
        goalkeeperMonthlyFee: goalkeeperFee,
        goalIcon:            _icons['goalIcon'],
        goalkeeperIcon:      _icons['goalkeeperIcon'],
        assistIcon:          _icons['assistIcon'],
        ownGoalIcon:         _icons['ownGoalIcon'],
        mvpIcon:             _icons['mvpIcon'],
        playerIcon:          _icons['playerIcon'],
        rank1Icon:           _icons['rank1Icon'],
        rank2Icon:           _icons['rank2Icon'],
        rank3Icon:           _icons['rank3Icon'],
        mvpTieRule:           _mvpTieRule,
        mvpTieMaxPlayers:     _mvpTieRule == 2 ? _mvpTieMaxPlayers : null,
        showPlayerStats:      _showPlayerStats,
        paymentDueDay:        _paymentMode == 0 ? _paymentDueDay : null,
        autoFinalizeMvpHours: _autoFinalizeMvpHours,
      );
      ref.invalidate(groupSettingsProvider(widget.groupId));
      if (mounted) {
        setState(() {
          _isPersisted = true;
          _saveMsgOk   = true;
          _saveMsg     = 'Configurações salvas com sucesso.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saveMsgOk = false;
          _saveMsg   = 'Erro ao salvar configurações.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Time picker ───────────────────────────────────────────────────────────

  Future<void> _pickTime() async {
    TimeOfDay initial = TimeOfDay.now();
    if (_kickoffTime != null) {
      final parts = _kickoffTime!.split(':');
      if (parts.length >= 2) {
        initial = TimeOfDay(
          hour:   int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null && mounted) {
      setState(() => _kickoffTime =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
    }
  }

  // ── Remove confirm ────────────────────────────────────────────────────────

  Future<void> _confirmRemove(
    GroupMember member, {
    required bool isAdminList,
  }) async {
    final role = isAdminList ? 'administrador' : 'financeiro';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmRemoveDialog(
        label: 'Remover "${member.displayName}" como $role desta patota?',
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final ds = ref.read(groupSettingsDsProvider);
      if (isAdminList) {
        await ds.removeAdmin(widget.groupId, member.userId);
      } else {
        await ds.removeFinanceiro(widget.groupId, member.userId);
      }
      ref.invalidate(groupDetailProvider(widget.groupId));
      // Atualiza as permissões locais ao remover admin/financeiro.
      ref.read(authNotifierProvider.notifier).refreshRoles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Membro removido com sucesso.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao remover: $e')),
        );
      }
    }
  }

  // ── Add member ────────────────────────────────────────────────────────────

  void _showAddMember({required bool isAdminRole}) {
    final detail = ref.read(groupDetailProvider(widget.groupId)).valueOrNull;
    final existing = isAdminRole
        ? Set<String>.from(detail?.adminIds ?? [])
        : Set<String>.from(detail?.financeiroIds ?? []);

    showDialog(
      context: context,
      builder: (_) => _AddMemberDialog(
        groupId:       widget.groupId,
        groupName:     detail?.name ?? '',
        isAdminRole:   isAdminRole,
        existingIds:   existing,
        ds:            ref.read(groupSettingsDsProvider),
        onAdded: () {
          ref.invalidate(groupDetailProvider(widget.groupId));
          // Atualiza as permissões locais imediatamente para quem foi promovido
          // ver os botões de admin/financeiro sem precisar fazer logout.
          ref.read(authNotifierProvider.notifier).refreshRoles();
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final detailAsync = ref.watch(groupDetailProvider(widget.groupId));
    final detail      = detailAsync.valueOrNull;

    return Scaffold(
      body: CustomScrollView(
        slivers: [

          // ── 1. Header ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _buildHeader(detail?.name),
          ),

          // ── 2. Configurações (tabbed) ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: _CardSection(
                iconBg:   const Color(0xFF2563EB),
                icon:     Icons.settings_outlined,
                title:    'Configurações',
                subtitle: 'Regras, pagamento, MVP e ícones da patota',
                child: _buildTabbedSettings(isDark),
              ),
            ),
          ),

          // ── 3. Equipe da patota ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: _CardSection(
                iconBg:  const Color(0xFF334155),
                icon:    Icons.group_outlined,
                title:   'Equipe da patota',
                subtitle: 'Administradores e responsáveis financeiros',
                child: _buildTeam(isDark, detail: detail, detailAsync: detailAsync),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section 1: Header ─────────────────────────────────────────────────────

  Widget _buildHeader(String? groupName) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
        begin:  Alignment.topLeft,
        end:    Alignment.bottomRight,
      ),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color:        Colors.white.withAlpha(25),
                borderRadius: BorderRadius.circular(16),
                border:       Border.all(color: Colors.white.withAlpha(50)),
              ),
              child: const Icon(Icons.settings_outlined,
                  size: 26, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    groupName ?? 'Configurações',
                    style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Configure regras, ícones e gerencie a equipe da patota.',
                    style: TextStyle(
                      color:    Colors.white.withAlpha(128),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ── Tab bar ───────────────────────────────────────────────────────────────

  static const _kTabLabels = ['Geral', 'Pagamento', 'MVP', 'Ícones'];

  Widget _buildTabbedSettings(bool isDark) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildTabBar(isDark),
      const SizedBox(height: 16),
      if (_activeTab == 0) _buildTabGeral(isDark),
      if (_activeTab == 1) _buildTabPagamento(isDark),
      if (_activeTab == 2) _buildTabMvp(isDark),
      if (_activeTab == 3) _buildIcons(isDark),
      const SizedBox(height: 20),
      _buildSaveButton(isDark),
    ],
  );

  Widget _buildTabBar(bool isDark) => Container(
    decoration: BoxDecoration(
      color: isDark ? AppColors.slate800 : AppColors.slate100,
      borderRadius: BorderRadius.circular(10),
    ),
    padding: const EdgeInsets.all(4),
    child: Row(
      children: [
        for (var i = 0; i < _kTabLabels.length; i++)
          Expanded(child: _buildTabBtn(i, _kTabLabels[i], isDark)),
      ],
    ),
  );

  Widget _buildTabBtn(int idx, String label, bool isDark) {
    final sel = _activeTab == idx;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: sel
              ? (isDark ? AppColors.slate700 : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: sel
              ? [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
            color: sel
                ? (isDark ? Colors.white : AppColors.slate900)
                : (isDark ? AppColors.slate400 : AppColors.slate500),
          ),
        ),
      ),
    );
  }

  // ── Tab 0: Geral ──────────────────────────────────────────────────────────

  Widget _buildTabGeral(bool isDark) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _subCard(
        isDark:    isDark,
        accentBg:  const Color(0xFFEEF2FF),
        accentFg:  const Color(0xFF4F46E5),
        icon:      Icons.group_outlined,
        title:     'Jogadores',
        subtitle:  'Por partida',
        child: Row(
          children: [
            Expanded(child: _labeledInput(
              label: 'Mínimo', ctrl: _minCtrl, hint: '5',
              isDark: isDark, type: TextInputType.number,
              fmts: [FilteringTextInputFormatter.digitsOnly],
            )),
            const SizedBox(width: 12),
            Expanded(child: _labeledInput(
              label: 'Máximo', ctrl: _maxCtrl, hint: '6',
              isDark: isDark, type: TextInputType.number,
              fmts: [FilteringTextInputFormatter.digitsOnly],
            )),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _subCard(
        isDark:   isDark,
        accentBg: const Color(0xFFFFFBEB),
        accentFg: const Color(0xFFD97706),
        icon:     Icons.calendar_today_outlined,
        title:    'Padrões',
        subtitle: 'Local, dia e horário',
        child: Column(
          children: [
            _labeledInput(
              label: 'Local padrão', ctrl: _placeCtrl,
              hint: 'Ex: Boca Jrs', isDark: isDark,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _DayDropdown(
                  label: 'Dia', value: _dayOfWeek, isDark: isDark,
                  onChanged: (v) => setState(() => _dayOfWeek = v),
                )),
                const SizedBox(width: 12),
                Expanded(child: _TimeField(
                  label: 'Horário', value: _kickoffTime,
                  isDark: isDark, onTap: _pickTime,
                )),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate700 : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.bar_chart_rounded, size: 18,
                  color: isDark ? AppColors.slate300 : const Color(0xFF2563EB)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Exibir gols e assistências',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.slate100 : AppColors.slate900)),
                  const SizedBox(height: 2),
                  Text('Jogadores comuns poderão ver gols e assistências.',
                      style: TextStyle(fontSize: 11,
                          color: isDark ? AppColors.slate400 : AppColors.slate500)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: _showPlayerStats,
              onChanged: (v) => setState(() => _showPlayerStats = v),
              activeThumbColor: isDark ? AppColors.slate100 : AppColors.slate900,
            ),
          ],
        ),
      ),
    ],
  );

  // ── Tab 1: Pagamento ──────────────────────────────────────────────────────

  Widget _buildTabPagamento(bool isDark) => _subCard(
    isDark:   isDark,
    accentBg: const Color(0xFFECFDF5),
    accentFg: const Color(0xFF059669),
    icon:     Icons.payments_outlined,
    title:    'Pagamento',
    subtitle: 'Modo de cobrança',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _payModeBtn(0, 'Mensal',   isDark)),
            const SizedBox(width: 8),
            Expanded(child: _payModeBtn(1, 'Por jogo', isDark)),
          ],
        ),
        if (_paymentMode == 0) ...[
          const SizedBox(height: 12),
          _labeledInput(
            label: 'Mensalidade Jogador (R\$)', ctrl: _feeCtrl,
            hint: 'Ex: 50.00', isDark: isDark,
            type: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 8),
          _labeledInput(
            label: 'Mensalidade Goleiro (R\$)', ctrl: _goalkeeperFeeCtrl,
            hint: 'Padrão: igual ao jogador', isDark: isDark,
            type: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          _DueDayDropdown(
            label:     'Dia de vencimento',
            value:     _paymentDueDay,
            isDark:    isDark,
            onChanged: (v) => setState(() => _paymentDueDay = v),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          _paymentMode == 0
              ? 'Cobrado mensalmente ao encerrar uma partida.'
              : 'O financeiro define o valor ao encerrar cada partida.',
          style: TextStyle(fontSize: 11,
              color: isDark ? AppColors.slate500 : AppColors.slate400),
        ),
      ],
    ),
  );

  // ── Tab 2: MVP ────────────────────────────────────────────────────────────

  Widget _buildTabMvp(bool isDark) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _subCard(
        isDark:   isDark,
        accentBg: const Color(0xFFFFFBEB),
        accentFg: const Color(0xFFD97706),
        icon:     Icons.emoji_events_outlined,
        title:    'Empate no MVP',
        subtitle: 'O que acontece quando dois ou mais jogadores empatam em votos',
        child: _buildMvpTieRule(isDark),
      ),
      const SizedBox(height: 12),
      _subCard(
        isDark:   isDark,
        accentBg: const Color(0xFFF0F9FF),
        accentFg: const Color(0xFF0284C7),
        icon:     Icons.timer_outlined,
        title:    'Encerrar votação MVP automaticamente',
        subtitle: 'Finaliza a partida após um tempo configurado',
        child: _buildAutoFinalizeSection(isDark),
      ),
    ],
  );

  // ── Save button (shared) ──────────────────────────────────────────────────

  Widget _buildSaveButton(bool isDark) => Row(
    children: [
      SizedBox(
        height: 44,
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_outlined, size: 15),
          label: Text(_saving ? 'Salvando…' : 'Salvar configurações',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      const SizedBox(width: 12),
      if (_saveMsg != null)
        Expanded(
          child: Text('${_saveMsgOk ? '✓ ' : '✕ '}$_saveMsg',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                  color: _saveMsgOk ? AppColors.emerald500 : AppColors.rose500)),
        )
      else if (!_isPersisted)
        const Expanded(
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 13, color: AppColors.amber500),
              SizedBox(width: 4),
              Flexible(
                child: Text('Usando valores padrão — salve para persistir.',
                    style: TextStyle(fontSize: 11, color: AppColors.amber500)),
              ),
            ],
          ),
        ),
    ],
  );

  // ── Section 2: Configurações gerais ──────────────────────────────────────

  Widget _buildGeneralConfig(bool isDark) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // 3 sub-cards in a column (mobile) — matches site's md:grid-cols-3
      _subCard(
        isDark:    isDark,
        accentBg:  const Color(0xFFEEF2FF),
        accentFg:  const Color(0xFF4F46E5),
        icon:      Icons.group_outlined,
        title:     'Jogadores',
        subtitle:  'Por partida',
        child: Row(
          children: [
            Expanded(child: _labeledInput(
              label: 'Mínimo', ctrl: _minCtrl, hint: '5',
              isDark: isDark,
              type: TextInputType.number,
              fmts: [FilteringTextInputFormatter.digitsOnly],
            )),
            const SizedBox(width: 12),
            Expanded(child: _labeledInput(
              label: 'Máximo', ctrl: _maxCtrl, hint: '6',
              isDark: isDark,
              type: TextInputType.number,
              fmts: [FilteringTextInputFormatter.digitsOnly],
            )),
          ],
        ),
      ),

      const SizedBox(height: 12),

      _subCard(
        isDark:   isDark,
        accentBg: const Color(0xFFFFFBEB),
        accentFg: const Color(0xFFD97706),
        icon:     Icons.calendar_today_outlined,
        title:    'Padrões',
        subtitle: 'Local, dia e horário',
        child: Column(
          children: [
            _labeledInput(
              label: 'Local padrão', ctrl: _placeCtrl,
              hint: 'Ex: Boca Jrs', isDark: isDark,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _DayDropdown(
                  label:     'Dia',
                  value:     _dayOfWeek,
                  isDark:    isDark,
                  onChanged: (v) => setState(() => _dayOfWeek = v),
                )),
                const SizedBox(width: 12),
                Expanded(child: _TimeField(
                  label:   'Horário',
                  value:   _kickoffTime,
                  isDark:  isDark,
                  onTap:   _pickTime,
                )),
              ],
            ),
          ],
        ),
      ),

      const SizedBox(height: 12),

      _subCard(
        isDark:   isDark,
        accentBg: const Color(0xFFECFDF5),
        accentFg: const Color(0xFF059669),
        icon:     Icons.payments_outlined,
        title:    'Pagamento',
        subtitle: 'Modo de cobrança',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toggle Mensal / Por jogo — mirrors site's radio buttons
            Row(
              children: [
                Expanded(child: _payModeBtn(0, 'Mensal',   isDark)),
                const SizedBox(width: 8),
                Expanded(child: _payModeBtn(1, 'Por jogo', isDark)),
              ],
            ),
            if (_paymentMode == 0) ...[
              const SizedBox(height: 12),
              _labeledInput(
                label: 'Mensalidade Jogador (R\$)',
                ctrl: _feeCtrl,
                hint: 'Ex: 50.00',
                isDark: isDark,
                type: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              _labeledInput(
                label: 'Mensalidade Goleiro (R\$)',
                ctrl: _goalkeeperFeeCtrl,
                hint: 'Padrão: igual ao jogador',
                isDark: isDark,
                type: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
            if (_paymentMode == 0) ...[
              const SizedBox(height: 12),
              _DueDayDropdown(
                label:     'Dia de vencimento',
                value:     _paymentDueDay,
                isDark:    isDark,
                onChanged: (v) => setState(() => _paymentDueDay = v),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _paymentMode == 0
                  ? 'Cobrado mensalmente ao encerrar uma partida.'
                  : 'O financeiro define o valor ao encerrar cada partida.',
              style: TextStyle(
                fontSize: 11,
                color:    isDark ? AppColors.slate500 : AppColors.slate400,
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 12),

      // ── Empate no MVP ─────────────────────────────────────────────────────
      _subCard(
        isDark:   isDark,
        accentBg: const Color(0xFFFFFBEB),
        accentFg: const Color(0xFFD97706),
        icon:     Icons.emoji_events_outlined,
        title:    'Empate no MVP',
        subtitle: 'O que acontece quando dois ou mais jogadores empatam em votos',
        child: _buildMvpTieRule(isDark),
      ),

      const SizedBox(height: 12),

      _subCard(
        isDark:   isDark,
        accentBg: const Color(0xFFF0F9FF),
        accentFg: const Color(0xFF0284C7),
        icon:     Icons.timer_outlined,
        title:    'Encerrar votação MVP automaticamente',
        subtitle: 'Finaliza a partida automaticamente após um tempo configurado',
        child: _buildAutoFinalizeSection(isDark),
      ),

      const SizedBox(height: 12),

      // ── Exibir gols e assistências ────────────────────────────────────────
      Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? AppColors.slate700 : AppColors.slate200),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.slate700
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.bar_chart_rounded,
                size: 18,
                color: isDark ? AppColors.slate300 : const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exibir gols e assistências',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.slate100 : AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Jogadores comuns poderão ver gols e assistências. Administradores sempre visualizam.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.slate400 : AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: _showPlayerStats,
              onChanged: (v) => setState(() => _showPlayerStats = v),
              activeThumbColor: isDark ? AppColors.slate100 : AppColors.slate900,
            ),
          ],
        ),
      ),

      const SizedBox(height: 20),

      // ── Save button + status ──────────────────────────────────────────────
      Row(
        children: [
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon:  _saving
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 15),
              label: Text(_saving ? 'Salvando…' : 'Salvar configurações',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (_saveMsg != null)
            Expanded(
              child: Text(
                '${_saveMsgOk ? '✓ ' : '✕ '}$_saveMsg',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _saveMsgOk ? AppColors.emerald500 : AppColors.rose500,
                ),
              ),
            )
          else if (!_isPersisted)
            const Expanded(
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 13, color: AppColors.amber500),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Usando valores padrão — salve para persistir.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.amber500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ],
  );

  Widget _payModeBtn(int mode, String label, bool isDark) {
    final selected = _paymentMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _paymentMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:  const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? Colors.white : AppColors.slate900)
              : (isDark ? AppColors.slate700 : AppColors.slate100),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? (isDark ? Colors.white : AppColors.slate900)
                : (isDark ? AppColors.slate600 : AppColors.slate200),
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize:   13,
              fontWeight: FontWeight.w600,
              color:      selected
                  ? (isDark ? AppColors.slate900 : Colors.white)
                  : (isDark ? AppColors.slate400 : AppColors.slate500),
            ),
          ),
        ),
      ),
    );
  }

  // ── MVP tie rule builder ─────────────────────────────────────────────────

  static const _kTieRules = [
    (val: 0, label: 'Nenhum recebe MVP',    desc: 'Em caso de empate, ninguém é eleito.'),
    (val: 1, label: 'Todos recebem MVP',    desc: 'Todos os empatados são eleitos MVPs.'),
    (val: 2, label: 'Todos até um máximo',  desc: 'Todos recebem MVP se o número de empatados não ultrapassar o limite.'),
  ];

  Widget _buildMvpTieRule(bool isDark) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Radio options
      for (final rule in _kTieRules) ...[
        GestureDetector(
          onTap: () => setState(() => _mvpTieRule = rule.val),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _mvpTieRule == rule.val
                  ? (isDark ? Colors.white : AppColors.slate900)
                  : (isDark ? AppColors.slate800 : Colors.white),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _mvpTieRule == rule.val
                    ? (isDark ? Colors.white : AppColors.slate900)
                    : (isDark ? AppColors.slate600 : AppColors.slate200),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.label,
                        style: TextStyle(
                          fontSize:   13,
                          fontWeight: FontWeight.w600,
                          color: _mvpTieRule == rule.val
                              ? (isDark ? AppColors.slate900 : Colors.white)
                              : (isDark ? Colors.white : AppColors.slate900),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rule.desc,
                        style: TextStyle(
                          fontSize: 11,
                          color: _mvpTieRule == rule.val
                              ? (isDark ? AppColors.slate500 : Colors.white70)
                              : (isDark ? AppColors.slate500 : AppColors.slate400),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (rule.val != _kTieRules.last.val) const SizedBox(height: 8),
      ],

      // Max players input — only when rule == 2
      if (_mvpTieRule == 2) ...[
        const SizedBox(height: 12),
        _labeledInput(
          label: 'Máximo de MVPs empatados',
          ctrl:  _mvpMaxCtrl,
          hint:  '2',
          isDark: isDark,
          type:  TextInputType.number,
          fmts:  [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) {
            final n = int.tryParse(v) ?? 2;
            setState(() => _mvpTieMaxPlayers = n < 2 ? 2 : n);
          },
        ),
        const SizedBox(height: 6),
        Text(
          'Se $_mvpTieMaxPlayers ou menos jogadores empatarem, todos recebem MVP. Se ultrapassar, ninguém recebe.',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.slate500 : AppColors.slate400,
          ),
        ),
      ],
    ],
  );

  Widget _buildAutoFinalizeSection(bool isDark) {
    final enabled = _autoFinalizeMvpHours != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                enabled
                    ? 'Finaliza automaticamente $_autoFinalizeMvpHours h após encerrar a partida.'
                    : 'Desativado — o admin finaliza manualmente.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.slate400 : AppColors.slate500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: enabled,
              onChanged: (v) => setState(() {
                if (v) {
                  _autoFinalizeMvpHours = 2;
                  _autoFinalizeCtrl.text = '2';
                } else {
                  _autoFinalizeMvpHours = null;
                  _autoFinalizeCtrl.clear();
                }
              }),
              activeThumbColor: isDark ? AppColors.slate100 : AppColors.slate900,
            ),
          ],
        ),
        if (enabled) ...[
          const SizedBox(height: 12),
          _labeledInput(
            label: 'Horas para encerrar após fim da partida',
            ctrl:  _autoFinalizeCtrl,
            hint:  'Ex: 2',
            isDark: isDark,
            type:  TextInputType.number,
            fmts:  [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) {
              final n = int.tryParse(v);
              setState(() => _autoFinalizeMvpHours = (n != null && n >= 1) ? n : 1);
            },
          ),
          const SizedBox(height: 6),
          Text(
            'Um lembrete será enviado 1 hora antes do encerramento automático.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.slate500 : AppColors.slate400,
            ),
          ),
        ],
      ],
    );
  }

  // ── Section 3: Ícones da patota ───────────────────────────────────────────

  Widget _buildIcons(bool isDark) => Column(
    children: [
      for (var i = 0; i < _kIconCats.length; i += 2) ...[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _iconCard(_kIconCats[i], isDark)),
            const SizedBox(width: 12),
            Expanded(
              child: i + 1 < _kIconCats.length
                  ? _iconCard(_kIconCats[i + 1], isDark)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    ],
  );

  Widget _iconCard(_IconCat cat, bool isDark) {
    final current = _icons[cat.key] ?? cat.defaultValue;
    return Container(
      decoration: BoxDecoration(
        color:        isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color:        isDark ? AppColors.slate800 : AppColors.slate100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: _IconRenderer(value: current, size: 20,
                      isDark: isDark),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                cat.label,
                style: TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.w600,
                  color:      isDark ? AppColors.slate100 : AppColors.slate800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: cat.options.map((opt) {
              final sel = _icons[cat.key] == opt.value;
              return GestureDetector(
                onTap: () => setState(() => _icons[cat.key] = opt.value),
                child: Tooltip(
                  message: opt.label,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: sel
                          ? (isDark ? AppColors.blue500.withAlpha(50) : AppColors.blue50)
                          : (isDark ? AppColors.slate800 : AppColors.slate100),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: sel ? AppColors.blue500
                            : (isDark ? AppColors.slate700 : AppColors.slate200),
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: _IconRenderer(value: opt.value, size: 18,
                          isDark: isDark),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Section 4: Equipe da patota ───────────────────────────────────────────

  Widget _buildTeam(
    bool isDark, {
    required GroupDetail? detail,
    required AsyncValue<GroupDetail> detailAsync,
  }) {
    if (detailAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child:   Row(children: [
          SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text('Carregando…',
              style: TextStyle(color: AppColors.slate400, fontSize: 13)),
        ]),
      );
    }
    if (detail == null) {
      return const Text(
        'Não foi possível carregar membros.',
        style: TextStyle(color: AppColors.rose500, fontSize: 13),
      );
    }

    final adminList = detail.adminUsers;
    final finList   = detail.financeiroUsers;
    final adminIds  = Set<String>.from(detail.adminIds);
    final finIds    = Set<String>.from(detail.financeiroIds);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Warning: sem financeiro
        if (finList.isEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color:        const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border:       Border.all(color: AppColors.amber200),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 15, color: AppColors.amber500),
                const SizedBox(width: 8),
                Flexible(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                      children: [
                        TextSpan(text: 'Sem financeiro cadastrado. ',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(
                          text: 'Nenhum usuário pode gerenciar pagamentos desta patota.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        _memberCard(
          isDark:      isDark,
          accentColor: const Color(0xFF7C3AED),
          borderColor: isDark ? AppColors.slate700 : const Color(0xFFDDD6FE),
          icon:        Icons.shield_outlined,
          title:       'Administradores',
          count:       adminList.length,
          members:     adminList,
          crossIds:    finIds,
          crossRole:   'Fin.',
          crossColor:  AppColors.emerald500,
          creatorId:   detail.createdByUserId,
          isAdminList: true,
          footerText:  'Gerenciam jogadores, partidas e configurações. O criador não pode ser removido.',
        ),
        const SizedBox(height: 12),
        _memberCard(
          isDark:      isDark,
          accentColor: const Color(0xFF059669),
          borderColor: isDark ? AppColors.slate700 : const Color(0xFFA7F3D0),
          icon:        Icons.account_balance_wallet_outlined,
          title:       'Financeiros',
          count:       finList.length,
          members:     finList,
          crossIds:    adminIds,
          crossRole:   'Adm.',
          crossColor:  const Color(0xFF7C3AED),
          creatorId:   null,
          isAdminList: false,
          footerText:  'Gerenciam pagamentos, mensalidades e cobranças.',
        ),
      ],
    );
  }

  Widget _memberCard({
    required bool              isDark,
    required Color             accentColor,
    required Color             borderColor,
    required IconData          icon,
    required String            title,
    required int               count,
    required List<GroupMember> members,
    required Set<String>       crossIds,
    required String            crossRole,
    required Color             crossColor,
    required String?           creatorId,
    required bool              isAdminList,
    required String            footerText,
  }) {
    final bg     = isDark ? AppColors.slate800 : Colors.white;
    final border = isDark ? AppColors.slate700 : borderColor;

    return Container(
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header bar ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.slate900
                  : accentColor.withAlpha(12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color:        accentColor,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 15, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize:   13,
                          fontWeight: FontWeight.w700,
                          color:      isDark ? Colors.white : AppColors.slate800,
                        ),
                      ),
                      Text(
                        '$count ${count == 1 ? 'membro' : 'membros'}',
                        style: TextStyle(
                          fontSize: 11,
                          color:    isDark ? AppColors.slate500 : accentColor.withAlpha(180),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Add button
                TextButton.icon(
                  onPressed: () => _showAddMember(isAdminRole: isAdminList),
                  icon: Icon(Icons.add_rounded, size: 14, color: accentColor),
                  label: Text(
                    'Adicionar',
                    style: TextStyle(
                      fontSize:   12,
                      fontWeight: FontWeight.w600,
                      color:      accentColor,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding:         const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    backgroundColor: isDark
                        ? accentColor.withAlpha(30)
                        : accentColor.withAlpha(18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: isDark ? AppColors.slate700 : borderColor.withAlpha(120)),

          // ── Member list ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (members.isEmpty)
                  _emptyMemberState(
                    isDark:      isDark,
                    accentColor: accentColor,
                    isAdminList: isAdminList,
                    onAdd:       () => _showAddMember(isAdminRole: isAdminList),
                  )
                else
                  ...members.map((m) {
                    final isCreator     = creatorId != null && m.userId == creatorId;
                    final isCurrentUser = m.userId == widget.account.userId;
                    final hasCross      = crossIds.contains(m.userId);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          // Avatar
                          _avatar(m.displayName, accentColor),
                          const SizedBox(width: 10),

                          // Name + username + badges
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        m.displayName,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize:   13,
                                          fontWeight: FontWeight.w600,
                                          color:      isDark
                                              ? AppColors.slate100
                                              : AppColors.slate800,
                                        ),
                                      ),
                                    ),
                                    if (isCurrentUser) ...[
                                      const SizedBox(width: 5),
                                      _badge('Você', AppColors.slate700, Colors.white),
                                    ],
                                    if (hasCross) ...[
                                      const SizedBox(width: 4),
                                      _badge(
                                        crossRole,
                                        crossColor.withAlpha(30),
                                        crossColor,
                                        border: crossColor.withAlpha(70),
                                      ),
                                    ],
                                  ],
                                ),
                                if (m.userName != null && m.userName!.isNotEmpty)
                                  Text(
                                    '@${m.userName}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppColors.slate500
                                          : AppColors.slate400,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Right action: Criador badge OR remove button
                          if (isCreator)
                            _badge('Criador', const Color(0xFFFEF3C7),
                                const Color(0xFFB45309),
                                border: AppColors.amber200)
                          else
                            GestureDetector(
                              onTap: () => _confirmRemove(m, isAdminList: isAdminList),
                              child: Container(
                                width: 30, height: 30,
                                decoration: BoxDecoration(
                                  color:        isDark
                                      ? AppColors.rose500.withAlpha(20)
                                      : AppColors.rose50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppColors.rose200),
                                ),
                                child: const Icon(Icons.remove_circle_outline_rounded,
                                    size: 14, color: AppColors.rose500),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),

                // Footer
                const SizedBox(height: 4),
                Text(
                  footerText,
                  style: TextStyle(
                    fontSize: 11,
                    color:    isDark ? AppColors.slate600 : AppColors.slate400,
                    height:   1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _emptyMemberState({
    required bool     isDark,
    required Color    accentColor,
    required bool     isAdminList,
    required VoidCallback onAdd,
  }) {
    final icon  = isAdminList ? Icons.shield_outlined : Icons.account_balance_wallet_outlined;
    final title = isAdminList ? 'Sem administradores' : 'Sem financeiros';
    final sub   = isAdminList
        ? 'Adicione um admin para gerenciar a patota.'
        : 'Adicione um financeiro para gerenciar cobranças.';

    return Container(
      margin:  const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color:        isDark
            ? accentColor.withAlpha(12)
            : accentColor.withAlpha(8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accentColor.withAlpha(isDark ? 40 : 30),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color:        accentColor.withAlpha(isDark ? 40 : 25),
              shape:        BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: accentColor),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize:   13,
              fontWeight: FontWeight.w600,
              color:      isDark ? AppColors.slate300 : AppColors.slate700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(
              fontSize:   11,
              color:      isDark ? AppColors.slate500 : AppColors.slate400,
              height:     1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color:        accentColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_add_outlined,
                      size: 13, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(
                    isAdminList ? 'Adicionar admin' : 'Adicionar financeiro',
                    style: const TextStyle(
                      fontSize:   12,
                      fontWeight: FontWeight.w600,
                      color:      Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subCard({
    required bool     isDark,
    required Color    accentBg,
    required Color    accentFg,
    required IconData icon,
    required String   title,
    required String   subtitle,
    required Widget   child,
  }) =>
      Container(
        decoration: BoxDecoration(
          color:        isDark ? AppColors.slate900 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? AppColors.slate700 : AppColors.slate200),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color:        isDark ? AppColors.slate800 : accentBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 17,
                      color: isDark ? AppColors.slate400 : accentFg),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                          fontSize:   13,
                          fontWeight: FontWeight.w600,
                          color:      isDark ? Colors.white : AppColors.slate900,
                        )),
                    Text(subtitle,
                        style: TextStyle(
                          fontSize: 10,
                          color:    isDark ? AppColors.slate500 : AppColors.slate400,
                        )),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );

  Widget _labeledInput({
    required String                  label,
    required TextEditingController   ctrl,
    required String                  hint,
    required bool                    isDark,
    TextInputType?                   type,
    List<TextInputFormatter>?        fmts,
    ValueChanged<String>?            onChanged,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                fontSize:   11,
                fontWeight: FontWeight.w500,
                color:      isDark ? AppColors.slate400 : AppColors.slate500,
              )),
          const SizedBox(height: 5),
          TextField(
            controller:      ctrl,
            keyboardType:    type,
            inputFormatters: fmts,
            onChanged:       onChanged,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.slate100 : AppColors.slate800,
            ),
            decoration: InputDecoration(
              hintText:  hint,
              hintStyle: TextStyle(
                  color: isDark ? AppColors.slate600 : AppColors.slate400),
              filled:    true,
              fillColor: isDark ? AppColors.slate800 : AppColors.slate50,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 9),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: isDark ? AppColors.slate700 : AppColors.slate200)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: isDark ? AppColors.slate700 : AppColors.slate200)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: AppColors.blue500, width: 1.5)),
            ),
          ),
        ],
      );

  Widget _avatar(String name, Color accentColor) {
    final colors = AppColors.gradientForName(name);
    final initials = name.isNotEmpty
        ? name.trim().split(' ').where((p) => p.isNotEmpty)
              .map((p) => p[0]).take(2).join().toUpperCase()
        : '?';
    return Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
        gradient:     LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Center(
        child: Text(initials,
            style: const TextStyle(
                color: Colors.white, fontSize: 11,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _badge(
    String text,
    Color bg,
    Color fg, {
    Color? border,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color:        bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border ?? bg),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize:   9,
                fontWeight: FontWeight.w600,
                color:      fg,
                height:     1.2)),
      );
}

// ── _CardSection wrapper ──────────────────────────────────────────────────────

class _CardSection extends StatelessWidget {
  final Color    iconBg;
  final IconData? icon;
  final String?  iconEmoji;
  final String   title;
  final String   subtitle;
  final Widget   child;

  const _CardSection({
    required this.iconBg,
    this.icon,
    this.iconEmoji,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color:        isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppColors.slate700 : AppColors.slate200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? AppColors.slate800 : AppColors.slate50,
            child: Row(
              children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color:        iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: iconEmoji != null
                      ? Center(child: Text(iconEmoji!,
                          style: const TextStyle(fontSize: 14)))
                      : Icon(icon!, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                          fontSize:   13,
                          fontWeight: FontWeight.w600,
                          color:      isDark ? Colors.white : AppColors.slate900,
                        )),
                    Text(subtitle,
                        style: TextStyle(
                          fontSize: 10,
                          color:    isDark ? AppColors.slate500 : AppColors.slate400,
                        )),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1,
              color: isDark ? AppColors.slate700 : AppColors.slate100),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── Icon Renderer ─────────────────────────────────────────────────────────────
// Mirrors the site's IconRenderer: emoji | lucide:* | letter:*

class _IconRenderer extends StatelessWidget {
  final String value;
  final double size;
  final bool   isDark;

  const _IconRenderer({
    required this.value,
    this.size   = 20,
    this.isDark = false,
  });

  static const _lucide = <String, IconData>{
    'Trophy':        Icons.emoji_events_outlined,
    'User':          Icons.person_outline,
    'Target':        Icons.gps_fixed,
    'Medal':         Icons.military_tech_outlined,
    'ShieldAlert':   Icons.shield_outlined,
    'Radar':         Icons.radar,
    'Link':          Icons.link_outlined,
    'Handshake':     Icons.handshake_outlined,
    'AlertTriangle': Icons.warning_amber_outlined,
    'Ban':           Icons.block_outlined,
    'Award':         Icons.workspace_premium_outlined,
    'Crown':         Icons.workspace_premium_outlined,
    'UserRound':     Icons.account_circle_outlined,
    'Shirt':         Icons.dry_cleaning_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final color = isDark ? AppColors.slate200 : AppColors.slate700;

    if (value.startsWith('lucide:')) {
      final name = value.substring(7);
      final data = _lucide[name];
      if (data != null) return Icon(data, size: size, color: color);
      return Text('?', style: TextStyle(fontSize: size * 0.7, color: color));
    }

    if (value.startsWith('letter:')) {
      final text  = value.substring(7);
      final scale = text.length <= 2 ? 0.85 : text.length == 3 ? 0.72 : 0.60;
      return Text(
        text,
        style: TextStyle(
          fontSize:      size * scale,
          fontWeight:    FontWeight.w800,
          letterSpacing: -0.8,
          height:        1,
          color:         color,
        ),
      );
    }

    // Emoji
    return Text(value, style: TextStyle(fontSize: size));
  }
}

// ── Day Dropdown ──────────────────────────────────────────────────────────────

class _DayDropdown extends StatelessWidget {
  final String   label;
  final int?     value;
  final bool     isDark;
  final ValueChanged<int?> onChanged;

  const _DayDropdown({
    required this.label,
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              fontSize:   11,
              fontWeight: FontWeight.w500,
              color:      isDark ? AppColors.slate400 : AppColors.slate500,
            )),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color:        isDark ? AppColors.slate800 : AppColors.slate50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isDark ? AppColors.slate700 : AppColors.slate200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value:         value,
              isExpanded:    true,
              dropdownColor: isDark ? AppColors.slate800 : Colors.white,
              style: TextStyle(
                fontSize: 13,
                color:    isDark ? AppColors.slate100 : AppColors.slate800,
              ),
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  color: isDark ? AppColors.slate400 : AppColors.slate500),
              onChanged: onChanged,
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Sem padrão',
                      style: TextStyle(
                          color: isDark
                              ? AppColors.slate500
                              : AppColors.slate400)),
                ),
                // 0=Domingo … 6=Sábado (mirrors site's DAY_OPTIONS)
                ...List.generate(7, (i) {
                  const labels = [
                    'Domingo', 'Segunda-feira', 'Terça-feira',
                    'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado',
                  ];
                  return DropdownMenuItem<int?>(
                    value: i,
                    child: Text(labels[i]),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Due Day Dropdown ──────────────────────────────────────────────────────────

class _DueDayDropdown extends StatelessWidget {
  final String   label;
  final int?     value;
  final bool     isDark;
  final ValueChanged<int?> onChanged;

  const _DueDayDropdown({
    required this.label,
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              fontSize:   11,
              fontWeight: FontWeight.w500,
              color:      isDark ? AppColors.slate400 : AppColors.slate500,
            )),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color:        isDark ? AppColors.slate800 : AppColors.slate50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isDark ? AppColors.slate700 : AppColors.slate200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value:         value,
              isExpanded:    true,
              dropdownColor: isDark ? AppColors.slate800 : Colors.white,
              style: TextStyle(
                fontSize: 13,
                color:    isDark ? AppColors.slate100 : AppColors.slate800,
              ),
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  color: isDark ? AppColors.slate400 : AppColors.slate500),
              onChanged: onChanged,
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Sem lembrete',
                      style: TextStyle(
                          color: isDark
                              ? AppColors.slate500
                              : AppColors.slate400)),
                ),
                ...List.generate(28, (i) => DropdownMenuItem<int?>(
                  value: i + 1,
                  child: Text('Dia ${i + 1}'),
                )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value != null
              ? 'Lembrete no dia 1 e no dia $value de cada mês para quem ainda não pagou.'
              : 'Nenhum lembrete de vencimento será enviado.',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.slate500 : AppColors.slate400,
          ),
        ),
      ],
    );
  }
}

// ── Time Field ────────────────────────────────────────────────────────────────

class _TimeField extends StatelessWidget {
  final String       label;
  final String?      value;
  final bool         isDark;
  final VoidCallback onTap;

  const _TimeField({
    required this.label,
    required this.value,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              fontSize:   11,
              fontWeight: FontWeight.w500,
              color:      isDark ? AppColors.slate400 : AppColors.slate500,
            )),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color:        isDark ? AppColors.slate800 : AppColors.slate50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isDark ? AppColors.slate700 : AppColors.slate200),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size:  14,
                    color: isDark ? AppColors.slate400 : AppColors.slate500),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    value ?? '--:--',
                    style: TextStyle(
                      fontSize: 13,
                      color: value != null
                          ? (isDark ? AppColors.slate100 : AppColors.slate800)
                          : (isDark ? AppColors.slate600 : AppColors.slate400),
                    ),
                  ),
                ),
                Icon(Icons.edit_outlined,
                    size:  12,
                    color: isDark ? AppColors.slate500 : AppColors.slate400),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Add Member Dialog ─────────────────────────────────────────────────────────

class _AddMemberDialog extends StatefulWidget {
  final String                        groupId;
  final String                        groupName;
  final bool                          isAdminRole;
  final Set<String>                   existingIds;
  final GroupSettingsRemoteDataSource ds;
  final VoidCallback                  onAdded;

  const _AddMemberDialog({
    required this.groupId,
    required this.groupName,
    required this.isAdminRole,
    required this.existingIds,
    required this.ds,
    required this.onAdded,
  });

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _ctrl = TextEditingController();

  List<GroupMember>   _allPlayers = [];
  List<GroupMember>   _results    = [];
  bool                _loading    = true;
  String?             _searchErr;
  Set<String>         _added      = {};
  Map<String, bool>   _adding     = {};
  Map<String, String> _addErr     = {};

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadPlayers() async {
    try {
      final players = await widget.ds.fetchGroupPlayers(widget.groupId);
      if (mounted) setState(() { _allPlayers = players; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _searchErr = extractDioError(e, 'Erro ao carregar membros.'); });
    }
  }

  void _search(String query) {
    final q = query.trim().toLowerCase();
    if (q.length < 2) {
      setState(() { _results = []; _searchErr = null; });
      return;
    }
    setState(() {
      _searchErr = null;
      _results = _allPlayers.where((m) {
        final name     = m.displayName.toLowerCase();
        final login    = (m.userName ?? '').toLowerCase();
        return name.contains(q) || login.contains(q);
      }).toList();
    });
  }

  Future<void> _add(GroupMember user) async {
    setState(() => _adding = {..._adding, user.userId: true});
    try {
      if (widget.isAdminRole) {
        await widget.ds.addAdmin(widget.groupId, user.userId);
      } else {
        await widget.ds.addFinanceiro(widget.groupId, user.userId);
      }
      widget.onAdded();
      if (mounted) setState(() { _added = {..._added, user.userId}; });
    } catch (e) {
      if (mounted) {
        setState(() => _addErr = {..._addErr, user.userId: 'Erro ao adicionar.'});
      }
    } finally {
      if (mounted) {
        setState(() {
          final m = Map<String, bool>.from(_adding);
          m.remove(user.userId);
          _adding = m;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final roleLabel = widget.isAdminRole ? 'admin' : 'financeiro';
    final roleColor = widget.isAdminRole
        ? const Color(0xFF7C3AED)
        : const Color(0xFF059669);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: isDark ? AppColors.slate700 : AppColors.slate100)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color:        roleColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_add_outlined,
                        size: 17, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Adicionar $roleLabel',
                            style: TextStyle(
                              fontSize:   14,
                              fontWeight: FontWeight.w700,
                              color:      isDark ? Colors.white : AppColors.slate900,
                            )),
                        Text(widget.groupName,
                            style: TextStyle(
                              fontSize: 11,
                              color:    isDark ? AppColors.slate500 : AppColors.slate400,
                            ),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    color: isDark ? AppColors.slate400 : AppColors.slate500,
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _ctrl,
                autofocus:  true,
                onChanged:  _search,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.slate100 : AppColors.slate800,
                ),
                decoration: InputDecoration(
                  hintText:  'Buscar por nome ou username...',
                  hintStyle: TextStyle(
                      color: isDark ? AppColors.slate500 : AppColors.slate400,
                      fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, size: 18,
                      color: isDark ? AppColors.slate400 : AppColors.slate400),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2)))
                      : null,
                  filled:    true,
                  fillColor: isDark ? AppColors.slate800 : AppColors.slate50,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: isDark ? AppColors.slate700 : AppColors.slate200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: isDark ? AppColors.slate700 : AppColors.slate200)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: roleColor, width: 1.5)),
                ),
              ),
            ),

            // Results
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    if (_searchErr != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(_searchErr!,
                            style: const TextStyle(
                                color: AppColors.rose500, fontSize: 12)),
                      )
                    else if (!_loading && _ctrl.text.trim().length < 2)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          _ctrl.text.trim().length == 1
                              ? 'Continue digitando...'
                              : 'Digite para buscar membros da patota.',
                          style: TextStyle(
                            fontSize: 12,
                            color:    isDark ? AppColors.slate500 : AppColors.slate400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else if (!_loading && _results.isEmpty &&
                        _ctrl.text.trim().length >= 2)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Nenhum membro encontrado para "${_ctrl.text}".',
                          style: TextStyle(
                            fontSize: 12,
                            color:    isDark ? AppColors.slate500 : AppColors.slate400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      for (final u in _results) ...[
                        _userRow(u, isDark, roleColor),
                        const SizedBox(height: 6),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _userRow(GroupMember u, bool isDark, Color roleColor) {
    final isExisting = widget.existingIds.contains(u.userId);
    final isAdded    = _added.contains(u.userId);
    final isAdding   = _adding[u.userId] == true;
    final err        = _addErr[u.userId];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color:        isDark ? AppColors.slate800 : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isDark ? AppColors.slate700 : AppColors.slate200),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color:        isDark ? AppColors.slate700 : AppColors.slate100,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(u.initials,
                      style: TextStyle(
                        fontSize:   12,
                        fontWeight: FontWeight.w700,
                        color:      isDark ? AppColors.slate200 : AppColors.slate600,
                      )),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.displayName,
                        style: TextStyle(
                          fontSize:   13,
                          fontWeight: FontWeight.w600,
                          color:      isDark ? Colors.white : AppColors.slate900,
                        )),
                    Text('@${u.userName ?? ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color:    isDark ? AppColors.slate500 : AppColors.slate400,
                        )),
                  ],
                ),
              ),
              // Action
              if (isExisting)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color:        isDark ? AppColors.slate700 : AppColors.slate100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isDark ? AppColors.slate600 : AppColors.slate200),
                  ),
                  child: Text('Já é ${widget.isAdminRole ? 'admin' : 'fin.'}',
                      style: TextStyle(
                        fontSize: 11,
                        color:    isDark ? AppColors.slate400 : AppColors.slate500,
                      )),
                )
              else if (isAdded)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color:        AppColors.emerald500.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.emerald500.withAlpha(80)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded,
                          size: 12, color: AppColors.emerald500),
                      SizedBox(width: 3),
                      Text('Adicionado',
                          style: TextStyle(
                            fontSize:  11,
                            color:     AppColors.emerald500,
                            fontWeight: FontWeight.w500,
                          )),
                    ],
                  ),
                )
              else
                FilledButton(
                  onPressed: isAdding ? null : () => _add(u),
                  style: FilledButton.styleFrom(
                    backgroundColor: roleColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  child: isAdding
                      ? const SizedBox(width: 12, height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_add_outlined,
                                size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(widget.isAdminRole ? 'Admin' : 'Fin.',
                                style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                ),
            ],
          ),
        ),
        if (err != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2),
            child: Text(err,
                style: const TextStyle(
                    color: AppColors.rose500, fontSize: 10)),
          ),
      ],
    );
  }
}

// ── Confirm Remove Dialog ─────────────────────────────────────────────────────

class _ConfirmRemoveDialog extends StatefulWidget {
  final String label;
  const _ConfirmRemoveDialog({required this.label});

  @override
  State<_ConfirmRemoveDialog> createState() => _ConfirmRemoveDialogState();
}

class _ConfirmRemoveDialogState extends State<_ConfirmRemoveDialog> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 20, color: AppColors.rose500),
                const SizedBox(width: 8),
                Text('Confirmar remoção',
                    style: TextStyle(
                      fontSize:   15,
                      fontWeight: FontWeight.w700,
                      color:      isDark ? Colors.white : AppColors.slate900,
                    )),
              ],
            ),
            const SizedBox(height: 12),
            Text(widget.label,
                style: TextStyle(
                  fontSize: 13,
                  color:    isDark ? AppColors.slate300 : AppColors.slate700,
                )),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading
                      ? null
                      : () async {
                          setState(() => _loading = true);
                          Navigator.pop(context, true);
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rose600,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Confirmar remoção'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty / Error states ──────────────────────────────────────────────────────

class _NoGroupState extends StatelessWidget {
  final String message;
  const _NoGroupState({required this.message});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.settings_outlined, size: 52, color: AppColors.slate500),
        const SizedBox(height: 12),
        const Text('Sem acesso',
            style: TextStyle(color: AppColors.slate400, fontSize: 16)),
        const SizedBox(height: 4),
        Text(message,
            textAlign: TextAlign.center,
            style:     const TextStyle(color: AppColors.slate500, fontSize: 13)),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.rose500),
          const SizedBox(height: 12),
          const Text('Erro ao carregar configurações',
              style: TextStyle(
                  fontSize:   16,
                  fontWeight: FontWeight.w600,
                  color:      AppColors.slate400),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(message,
              style: const TextStyle(fontSize: 12, color: AppColors.slate500),
              textAlign: TextAlign.center,
              maxLines:  3,
              overflow:  TextOverflow.ellipsis),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon:  const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}

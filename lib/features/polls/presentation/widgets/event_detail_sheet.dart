import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../data/datasources/polls_remote_datasource.dart';
import '../../domain/entities/poll_detail.dart';
import '../providers/polls_provider.dart';
import 'close_poll_sheet.dart';

class EventDetailSheet extends ConsumerStatefulWidget {
  final PollDetail   poll;
  final String       groupId;
  final bool         isAdmin;
  final ValueChanged<PollDetail> onUpdated;
  final VoidCallback? onDeleted;

  const EventDetailSheet({
    super.key,
    required this.poll,
    required this.groupId,
    required this.isAdmin,
    required this.onUpdated,
    this.onDeleted,
  });

  @override
  ConsumerState<EventDetailSheet> createState() => _EventDetailSheetState();
}

class _EventDetailSheetState extends ConsumerState<EventDetailSheet> {
  late PollDetail _poll;
  bool _saving    = false;
  bool _adminOpen = false;
  int  _tab       = 0; // 0 = Resultados, 1 = Presenças

  // Admin member vote state: playerId → selected option id
  final Map<String, String?> _memberSelections = {};

  // Local guest cache: playerId → guests (optimistic, supplements API data)
  final Map<String, List<PollGuest>> _localGuests = {};

  @override
  void initState() {
    super.initState();
    _poll = widget.poll;
    // Seed local guest cache from poll data
    for (final v in _poll.votes ?? <PollVote>[]) {
      if (v.guests.isNotEmpty) _localGuests[v.playerId] = List.of(v.guests);
    }
  }

  PollsRemoteDataSource get _ds => ref.read(pollsDsProvider);

  String? get _myVote => _poll.myVotedOptionIds.isNotEmpty ? _poll.myVotedOptionIds.first : null;

  String? get _myPlayerId => ref.read(accountStoreProvider).activeAccount?.activePlayerId;
  String  get _myPlayerName => ref.read(accountStoreProvider).activeAccount?.name ?? '';

  String? get _goingOptionId {
    try {
      return _poll.options.firstWhere(
        (o) => o.text.toLowerCase() == 'sim',
      ).id;
    } catch (_) {
      return _poll.options.isNotEmpty ? _poll.options.first.id : null;
    }
  }

  bool get _iVotedToGo {
    final goId = _goingOptionId;
    return goId != null && _poll.myVotedOptionIds.contains(goId);
  }

  List<PollGuest> _guestsForPlayer(String playerId) {
    if (_localGuests.containsKey(playerId)) {
      return _localGuests[playerId]!;
    }
    final vote = _poll.votes?.where((v) => v.playerId == playerId).firstOrNull;
    return vote?.guests ?? const [];
  }

  List<PollGuest> get _myGuests {
    final myId = _myPlayerId;
    if (myId == null) return const [];
    return _guestsForPlayer(myId);
  }

  String _formatDate(String? d) {
    if (d == null) return '';
    final p = d.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : d;
  }

  String? _formatCost() {
    if (_poll.costType == null || _poll.costType!.isEmpty) return null;
    final label = _poll.costType == 'individual' ? 'por pessoa' : 'rateio grupo';
    if (_poll.costAmount != null) return 'R\$ ${_poll.costAmount!.toStringAsFixed(2)} $label';
    return label;
  }

  Future<void> _vote(String optionId) async {
    if (_saving) return;
    final isRemoving = _myVote == optionId;
    setState(() => _saving = true);
    try {
      final updated = isRemoving
          ? await _ds.removeVote(widget.groupId, _poll.id)
          : await _ds.castVote(widget.groupId, _poll.id, [optionId]);
      setState(() {
        _poll = updated;
        // Reseed local guests from updated poll data
        for (final v in updated.votes ?? <PollVote>[]) {
          if (!_localGuests.containsKey(v.playerId) && v.guests.isNotEmpty) {
            _localGuests[v.playerId] = List.of(v.guests);
          }
        }
        // If user unvoted, clear their local guests
        if (isRemoving) {
          final myId = _myPlayerId;
          if (myId != null) _localGuests.remove(myId);
        }
      });
      widget.onUpdated(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao votar: $e'), backgroundColor: AppColors.rose500),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _adminVote(String playerId, String? optionId) async {
    if (optionId == null) return;
    setState(() => _saving = true);
    try {
      final updated = await _ds.adminCastVote(widget.groupId, _poll.id, playerId, [optionId]);
      setState(() {
        _poll = updated;
        _memberSelections[playerId] = optionId;
      });
      widget.onUpdated(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.rose500),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _closePoll() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClosePollSheet(pollTitle: _poll.title),
    );
    if (result == null) return;
    setState(() => _saving = true);
    try {
      await _ds.closePoll(widget.groupId, _poll.id, result);
      final updated = await _ds.getPoll(widget.groupId, _poll.id);
      setState(() => _poll = updated);
      widget.onUpdated(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.rose500),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reopenPoll() async {
    setState(() => _saving = true);
    try {
      await _ds.reopenPoll(widget.groupId, _poll.id);
      final updated = await _ds.getPoll(widget.groupId, _poll.id);
      setState(() => _poll = updated);
      widget.onUpdated(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.rose500),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deletePoll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir evento'),
        content: Text('Deseja excluir "${_poll.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _saving = true);
    try {
      await _ds.deletePoll(widget.groupId, _poll.id);
      widget.onDeleted?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.rose500),
        );
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _toggleAllowGuests() async {
    final next = !_poll.allowGuests;
    setState(() => _saving = true);
    try {
      await _ds.setAllowGuests(widget.groupId, _poll.id, next);
      final updated = _poll.copyWith(allowGuests: next);
      setState(() => _poll = updated);
      widget.onUpdated(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.rose500),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showAddGuestForm() async {
    if (!_poll.isAcceptingVotes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O prazo deste evento já encerrou.')),
      );
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddGuestSheet(
        onAdd: (name, isAdult) => _addGuest(name, isAdult),
      ),
    );
  }

  Future<void> _addGuest(String name, bool isAdult) async {
    if (!_poll.isAcceptingVotes) return;
    final myId = _myPlayerId;
    if (myId == null) return;

    final tempId  = 'tmp_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = PollGuest(id: tempId, name: name, isAdult: isAdult);
    setState(() {
      _localGuests[myId] = [..._guestsForPlayer(myId), optimistic];
    });

    try {
      final saved = await _ds.addGuest(widget.groupId, _poll.id, {
        'name': name,
        'isAdult': isAdult,
      });
      if (mounted) {
        setState(() {
          final list = List<PollGuest>.of(_localGuests[myId] ?? []);
          final idx  = list.indexWhere((g) => g.id == tempId);
          if (idx >= 0) { list[idx] = saved; } else { list.add(saved); }
          _localGuests[myId] = list;
        });
      }
    } catch (_) {
      // Backend may not support guests yet; keep local state
    }
  }

  Future<void> _removeGuest(PollGuest guest) async {
    if (!_poll.isAcceptingVotes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O prazo deste evento já encerrou.')),
      );
      return;
    }
    final myId = _myPlayerId;
    if (myId == null) return;
    setState(() {
      _localGuests[myId] = _guestsForPlayer(myId).where((g) => g.id != guest.id).toList();
    });
    try {
      await _ds.removeGuest(widget.groupId, _poll.id, guest.id);
    } catch (_) {
      // Backend may not support guests yet; local removal is enough
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final icon   = _poll.eventIcon ?? '📅';
    final cost   = _formatCost();
    final total  = _poll.totalVoters;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize:     0.95,
      minChildSize:     0.5,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 8),
            Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.slate300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 4),

            // Content
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  // ── Header ──
                  Row(
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_poll.title, style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.slate900,
                            )),
                            if (_poll.description != null)
                              Text(_poll.description!, style: TextStyle(
                                fontSize: 13, color: isDark ? AppColors.slate400 : AppColors.slate500,
                              )),
                          ],
                        ),
                      ),
                      _StatusChip(isOpen: _poll.isOpen),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Meta info ──
                  Wrap(spacing: 12, runSpacing: 6, children: [
                    if (_poll.eventDate != null)
                      _InfoChip(icon: Icons.calendar_today_outlined,
                        label: '${_formatDate(_poll.eventDate)}${_poll.eventTime != null ? ' às ${_poll.eventTime}' : ''}'),
                    if (_poll.eventLocation != null)
                      _InfoChip(icon: Icons.location_on_outlined, label: _poll.eventLocation!),
                    if (cost != null)
                      _InfoChip(icon: Icons.attach_money, label: cost, color: Colors.amber.shade700),
                    if (_poll.deadlineDate != null)
                      _InfoChip(
                        icon: Icons.schedule,
                        label: 'Prazo: ${_formatDate(_poll.deadlineDate)}${_poll.deadlineTime != null ? ' às ${_poll.deadlineTime}' : ''}',
                        color: _poll.deadlinePassed ? Colors.red.shade400 : null,
                      ),
                  ]),
                  const SizedBox(height: 20),

                  // ── RSVP buttons ──
                  if (_poll.isOpen) ...[
                    Text('SUA RESPOSTA', style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                      color: isDark ? AppColors.slate500 : AppColors.slate400,
                    )),
                    const SizedBox(height: 8),
                    Row(
                      children: _poll.options.map((opt) {
                        final isSelected = _poll.myVotedOptionIds.contains(opt.id);
                        final rsvpSymbol = opt.text == 'Sim' ? '✓'
                            : opt.text == 'Não' ? '✕' : '~';
                        final selBg = opt.text == 'Sim'
                            ? Colors.green.shade600
                            : opt.text == 'Não'
                                ? Colors.red.shade600
                                : Colors.amber.shade600;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _RsvpButton(
                              label: opt.text,
                              symbol: rsvpSymbol,
                              isSelected: isSelected,
                              saving: _saving,
                              onTap: () => _vote(opt.id),
                              selectedBg: selBg,
                              selectedBorder: selBg,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    // ── Guest section (visible only when allowGuests is on and user voted "Sim") ──
                    if (_poll.allowGuests && _iVotedToGo) ...[
                      const SizedBox(height: 12),
                      _GuestSection(
                        myGuests: _myGuests,
                        myPlayerName: _myPlayerName,
                        onAdd: _showAddGuestForm,
                        onRemove: _removeGuest,
                        isDark: isDark,
                        isAcceptingVotes: _poll.isAcceptingVotes,
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],

                  // ── Tab switcher ──
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? AppColors.slate700 : AppColors.slate100,
                        ),
                      ),
                    ),
                    child: Row(children: [
                      _TabChip(label: 'Resultados ($total)', selected: _tab == 0,
                        onTap: () => setState(() => _tab = 0), isDark: isDark),
                      _TabChip(label: 'Presenças', selected: _tab == 1,
                        onTap: () => setState(() => _tab = 1), isDark: isDark),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // ── Tab: Resultados ──
                  if (_tab == 0) ..._poll.options.map((opt) {
                    final pct    = total > 0 ? opt.voteCount / total : 0.0;
                    final voters = _poll.votes?.where((v) => v.optionId == opt.id).toList() ?? [];
                    return _ResultBar(
                      label: opt.text,
                      count: opt.voteCount,
                      pct: pct,
                      showVoters: _poll.showVotes,
                      voters: voters.map((v) => v.playerName).toList(),
                      isDark: isDark,
                    );
                  }),

                  // ── Tab: Presenças ──
                  if (_tab == 1)
                    _PresencasContent(
                      poll: _poll,
                      goingOptionId: _goingOptionId,
                      guestsForPlayer: _guestsForPlayer,
                      isDark: isDark,
                    ),

                  // ── Admin panel ──
                  if (widget.isAdmin) ...[
                    const SizedBox(height: 20),
                    _AdminPanel(
                      open: _adminOpen,
                      onToggle: () => setState(() => _adminOpen = !_adminOpen),
                      isDark: isDark,
                      child: _adminOpen ? _AdminContent(
                        poll: _poll,
                        saving: _saving,
                        selections: _memberSelections,
                        onVote: _adminVote,
                        onClose: _closePoll,
                        onReopen: _reopenPoll,
                        onDelete: _deletePoll,
                        onToggleAllowGuests: _toggleAllowGuests,
                        isDark: isDark,
                      ) : const SizedBox.shrink(),
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

// ── Reusable sub-widgets ───────────────────────────────────────────────────────

class _TabChip extends StatelessWidget {
  final String       label;
  final bool         selected;
  final VoidCallback onTap;
  final bool         isDark;

  const _TabChip({required this.label, required this.selected, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.only(bottom: 8, right: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected
                  ? (isDark ? Colors.white : AppColors.slate900)
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected
                ? (isDark ? Colors.white : AppColors.slate900)
                : (isDark ? AppColors.slate500 : AppColors.slate400),
          ),
        ),
      ),
    );
  }
}

class _GuestSection extends StatelessWidget {
  final List<PollGuest>           myGuests;
  final String                    myPlayerName;
  final VoidCallback              onAdd;
  final ValueChanged<PollGuest>   onRemove;
  final bool                      isDark;
  final bool                      isAcceptingVotes;

  const _GuestSection({
    required this.myGuests,
    required this.myPlayerName,
    required this.onAdd,
    required this.onRemove,
    required this.isDark,
    required this.isAcceptingVotes,
  });

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? AppColors.slate500 : AppColors.slate400;
    final divColor   = isDark ? AppColors.slate700 : AppColors.slate100;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: divColor)),
      ),
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.group_add_outlined, size: 13, color: labelColor),
              const SizedBox(width: 5),
              Text('MEUS CONVIDADOS', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 1.2,
                color: labelColor)),
              const Spacer(),
              if (isAcceptingVotes)
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white : AppColors.slate900,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('+ Adicionar', style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.slate900 : Colors.white)),
                  ),
                )
              else
                Text('Prazo encerrado', style: TextStyle(
                  fontSize: 11, fontStyle: FontStyle.italic,
                  color: isDark ? AppColors.slate500 : AppColors.slate400)),
            ],
          ),
          const SizedBox(height: 8),
          if (myGuests.isNotEmpty)
            ...myGuests.map((g) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? AppColors.slate800 : AppColors.slate100,
                      border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      g.name.isNotEmpty ? g.name[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.slate400 : AppColors.slate500),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: RichText(text: TextSpan(children: [
                    TextSpan(text: g.name, style: TextStyle(
                      fontSize: 12, color: isDark ? AppColors.slate200 : AppColors.slate700)),
                    TextSpan(text: '  ${g.isAdult ? 'Adulto' : 'Criança'}', style: TextStyle(
                      fontSize: 11, color: isDark ? AppColors.slate500 : AppColors.slate400)),
                  ]))),
                  GestureDetector(
                    onTap: () => onRemove(g),
                    child: Icon(Icons.close, size: 14,
                      color: isDark ? AppColors.slate600 : AppColors.slate300),
                  ),
                ],
              ),
            ))
          else
            Text('Nenhum convidado ainda.', style: TextStyle(
              fontSize: 12, fontStyle: FontStyle.italic,
              color: isDark ? AppColors.slate500 : AppColors.slate400)),
        ],
      ),
    );
  }
}

class _PresencasContent extends StatelessWidget {
  final PollDetail                    poll;
  final String?                       goingOptionId;
  final List<PollGuest> Function(String) guestsForPlayer;
  final bool                          isDark;

  const _PresencasContent({
    required this.poll,
    required this.goingOptionId,
    required this.guestsForPlayer,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final goId = goingOptionId;
    final goingVoters = goId == null
        ? (poll.votes ?? <PollVote>[])
        : (poll.votes?.where((v) => v.optionId == goId).toList() ?? <PollVote>[]);

    if (goingVoters.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('Nenhuma presença confirmada ainda.',
          style: TextStyle(fontSize: 13,
            color: isDark ? AppColors.slate400 : AppColors.slate500)),
      );
    }

    final nameColor   = isDark ? AppColors.slate200 : AppColors.slate700;
    final guestColor  = isDark ? AppColors.slate400 : AppColors.slate500;
    final divColor    = isDark ? AppColors.slate800 : AppColors.slate100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: goingVoters.map((vote) {
        final guests = guestsForPlayer(vote.playerId);
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Icon(Icons.check_circle_outline, size: 15,
                    color: Colors.green.shade500),
                  const SizedBox(width: 6),
                  Text(vote.playerName, style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: nameColor)),
                ]),
              ),
              ...guests.map((g) => Padding(
                padding: const EdgeInsets.only(left: 21, bottom: 6),
                child: Text(
                  '${g.name} (Convidado de ${vote.playerName} - ${g.isAdult ? 'Adulto' : 'Criança'})',
                  style: TextStyle(fontSize: 12, color: guestColor),
                ),
              )),
              Divider(height: 1, color: divColor),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _AddGuestSheet extends StatefulWidget {
  final void Function(String name, bool isAdult) onAdd;
  const _AddGuestSheet({required this.onAdd});

  @override
  State<_AddGuestSheet> createState() => _AddGuestSheetState();
}

class _AddGuestSheetState extends State<_AddGuestSheet> {
  final _ctrl    = TextEditingController();
  bool  _isAdult = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    widget.onAdd(name, _isAdult);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? AppColors.slate900 : Colors.white;
    final border = isDark ? AppColors.slate700 : AppColors.slate200;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              const SizedBox(height: 16),
              Text('Adicionar convidado', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.slate900,
              )),
              const SizedBox(height: 16),
              TextField(
                controller: _ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Nome do convidado',
                  filled: true,
                  fillColor: isDark ? AppColors.slate800 : AppColors.slate50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              // Adulto / Criança toggle
              Row(children: [
                _TypeButton(
                  label: 'Adulto',
                  selected: _isAdult,
                  onTap: () => setState(() => _isAdult = true),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _TypeButton(
                  label: 'Criança',
                  selected: !_isAdult,
                  onTap: () => setState(() => _isAdult = false),
                  isDark: isDark,
                ),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.slate900,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Confirmar', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String       label;
  final bool         selected;
  final VoidCallback onTap;
  final bool         isDark;

  const _TypeButton({required this.label, required this.selected, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.slate900 : (isDark ? AppColors.slate800 : AppColors.slate100),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.slate900 : (isDark ? AppColors.slate700 : AppColors.slate200)),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: selected ? Colors.white : (isDark ? AppColors.slate400 : AppColors.slate600),
        )),
      ),
    );
  }
}

class _RsvpButton extends StatelessWidget {
  final String       label;
  final String       symbol;
  final bool         isSelected;
  final bool         saving;
  final VoidCallback onTap;
  final Color        selectedBg;
  final Color        selectedBorder;

  const _RsvpButton({
    required this.label,
    required this.symbol,
    required this.isSelected,
    required this.saving,
    required this.onTap,
    required this.selectedBg,
    required this.selectedBorder,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idleBorder = isDark ? AppColors.slate700 : AppColors.slate200;
    final idleText   = isDark ? AppColors.slate300 : AppColors.slate600;

    return GestureDetector(
      onTap: saving ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? selectedBorder : idleBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(symbol, style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : idleText,
            )),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : idleText,
            )),
          ],
        ),
      ),
    );
  }
}

class _ResultBar extends StatelessWidget {
  final String       label;
  final int          count;
  final double       pct;
  final bool         showVoters;
  final List<String> voters;
  final bool         isDark;

  const _ResultBar({
    required this.label,
    required this.count,
    required this.pct,
    required this.showVoters,
    required this.voters,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final divColor = isDark ? AppColors.slate800 : AppColors.slate100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: divColor),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.slate200 : AppColors.slate700))),
                  Text('$count  ${(pct * 100).round()}%',
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.slate400 : AppColors.slate500)),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 3,
                  backgroundColor: isDark ? AppColors.slate800 : AppColors.slate100,
                  valueColor: const AlwaysStoppedAnimation(AppColors.slate900),
                ),
              ),
              if (showVoters && voters.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(voters.join(', '), style: TextStyle(fontSize: 11,
                  color: isDark ? AppColors.slate500 : AppColors.slate400)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isOpen;
  const _StatusChip({required this.isOpen});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: isOpen ? Colors.green.shade50 : AppColors.slate100,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: isOpen ? Colors.green.shade200 : AppColors.slate200),
    ),
    child: Text(isOpen ? 'Aberto' : 'Encerrado',
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
        color: isOpen ? Colors.green.shade700 : AppColors.slate500)),
  );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color?   color;
  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = color ?? (isDark ? AppColors.slate400 : AppColors.slate500);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: c),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, color: c)),
    ]);
  }
}

class _AdminPanel extends StatelessWidget {
  final bool open;
  final VoidCallback onToggle;
  final bool isDark;
  final Widget child;

  const _AdminPanel({required this.open, required this.onToggle, required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.admin_panel_settings_outlined, size: 18,
                    color: isDark ? AppColors.slate300 : AppColors.slate600),
                  const SizedBox(width: 8),
                  Text('Painel Admin', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.slate200 : AppColors.slate700)),
                  const Spacer(),
                  Icon(open ? Icons.expand_less : Icons.expand_more,
                    color: isDark ? AppColors.slate400 : AppColors.slate500),
                ],
              ),
            ),
          ),
          if (open) child,
        ],
      ),
    );
  }
}

class _AdminContent extends StatelessWidget {
  final PollDetail poll;
  final bool saving;
  final Map<String, String?> selections;
  final Function(String playerId, String? optionId) onVote;
  final VoidCallback onClose;
  final VoidCallback onReopen;
  final VoidCallback onDelete;
  final VoidCallback onToggleAllowGuests;
  final bool isDark;

  const _AdminContent({
    required this.poll,
    required this.saving,
    required this.selections,
    required this.onVote,
    required this.onClose,
    required this.onReopen,
    required this.onDelete,
    required this.onToggleAllowGuests,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final members = poll.members ?? [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: isDark ? AppColors.slate700 : AppColors.slate200),
          const SizedBox(height: 8),

          // Member responses
          if (members.isNotEmpty) ...[
            Text('Respostas dos membros', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: isDark ? AppColors.slate300 : AppColors.slate600)),
            const SizedBox(height: 8),
            ...members.map((m) {
              final voted   = m.votedOptionIds.isNotEmpty ? m.votedOptionIds.first : null;
              final current = selections[m.playerId] ?? voted;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(m.playerName, style: TextStyle(fontSize: 13,
                      color: isDark ? AppColors.slate200 : AppColors.slate700))),
                    DropdownButton<String?>(
                      value: current,
                      hint: const Text('—', style: TextStyle(fontSize: 13)),
                      isDense: true,
                      items: poll.options.map((opt) => DropdownMenuItem(
                        value: opt.id,
                        child: Text(opt.text, style: const TextStyle(fontSize: 13)),
                      )).toList(),
                      onChanged: saving ? null : (v) => onVote(m.playerId, v),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
          ],

          // Actions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: saving ? null : onToggleAllowGuests,
                icon: Icon(
                  poll.allowGuests ? Icons.group_outlined : Icons.group_off_outlined,
                  size: 15,
                ),
                label: Text(
                  poll.allowGuests ? 'Convidados: ativo' : 'Permitir convidados',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: poll.allowGuests ? Colors.purple.shade700 : null,
                ),
              ),
              if (poll.isOpen)
                OutlinedButton.icon(
                  onPressed: saving ? null : onClose,
                  icon: const Icon(Icons.lock_outlined, size: 15),
                  label: const Text('Encerrar', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade700),
                )
              else
                OutlinedButton.icon(
                  onPressed: saving ? null : onReopen,
                  icon: const Icon(Icons.lock_open_outlined, size: 15),
                  label: const Text('Reabrir', style: TextStyle(fontSize: 13)),
                ),
              OutlinedButton.icon(
                onPressed: saving ? null : onDelete,
                icon: const Icon(Icons.delete_outline, size: 15),
                label: const Text('Excluir', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

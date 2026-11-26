import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/feature_flags.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../data/discovery_datasource.dart';
import '../../domain/discovery_models.dart';

class DiscoverySearchPage extends ConsumerStatefulWidget {
  const DiscoverySearchPage({super.key, this.preferredMatchId, this.openingId});
  final String? preferredMatchId;
  final String? openingId;

  @override
  ConsumerState<DiscoverySearchPage> createState() =>
      _DiscoverySearchPageState();
}

class _DiscoverySearchPageState extends ConsumerState<DiscoverySearchPage> {
  final _query = TextEditingController();
  Timer? _timer;
  bool _showGroups = true;
  bool _loading = false;
  bool _waitingForDebounce = false;
  String? _error;
  int _searchVersion = 0;
  List<DiscoveryGroupItem> _groups = [];
  List<DiscoveryPlayerItem> _players = [];
  // Jogadores que já receberam convite nesta tela: mostra "Convite enviado" na
  // linha para o administrador ver que a ação foi concluída.
  final Set<String> _invited = {};

  @override
  void initState() {
    super.initState();
    if (widget.preferredMatchId != null) _showGroups = false;
  }

  DiscoveryDataSource get _api => DiscoveryDataSource(ref.read(dioProvider));

  @override
  void dispose() {
    _timer?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _timer?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _waitingForDebounce = false);
      _search();
      return;
    }
    // Dá retorno visual já no primeiro caractere e espera apenas o suficiente
    // para não disparar uma requisição para cada tecla. Os 280 ms anteriores,
    // somados à chamada HTTP, faziam uma busca local parecer lenta e ainda
    // exibiam o estado vazio antes de a consulta começar.
    setState(() => _waitingForDebounce = true);
    _timer = Timer(const Duration(milliseconds: 120), _search);
  }

  void _selectTab(bool groups) {
    if (_showGroups == groups) return;
    _timer?.cancel();
    setState(() => _showGroups = groups);
    _search();
  }

  Future<void> _search() async {
    final term = _query.text.trim();
    final groupsTab = _showGroups;
    final version = ++_searchVersion;

    if (term.isEmpty) {
      setState(() {
        _waitingForDebounce = false;
        _loading = false;
        _error = null;
        if (groupsTab) {
          _groups = [];
        } else {
          _players = [];
        }
      });
      return;
    }

    setState(() {
      _waitingForDebounce = false;
      _loading = true;
      _error = null;
    });
    try {
      if (groupsTab) {
        final results = await _api.groups(term);
        if (!mounted || version != _searchVersion) return;
        _groups = results;
      } else {
        final results = await _api.players(term,
            groupId:
                ref.read(accountStoreProvider).activeAccount?.activeGroupId);
        if (!mounted || version != _searchVersion) return;
        _players = results;
      }
    } catch (_) {
      if (mounted && version == _searchVersion) {
        setState(() {
          _error = 'Não foi possível fazer a busca. Verifique sua conexão.';
        });
      }
    } finally {
      if (mounted && version == _searchVersion) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _invite(DiscoveryPlayerItem player) async {
    final account = ref.read(accountStoreProvider).activeAccount;
    final groupId = account?.activeGroupId;
    if (groupId == null || !(account?.isGroupAdmin(groupId) ?? false)) return;
    final profile = await _api.group(groupId);
    if (!mounted) return;
    if (profile.matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('A patota não possui uma próxima partida.')),
      );
      return;
    }
    DiscoveryMatch? match;
    if (widget.preferredMatchId != null) {
      for (final candidate in profile.matches) {
        if (candidate.id.toLowerCase() ==
            widget.preferredMatchId!.toLowerCase()) {
          match = candidate;
          break;
        }
      }
    }
    match ??= await showModalBottomSheet<DiscoveryMatch>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Chamar ${player.name}',
              style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            const Text('Escolha a partida para ele conhecer a patota.'),
            const SizedBox(height: 16),
            ...profile.matches.map(
              (item) => ListTile(
                onTap: () => Navigator.pop(sheetContext, item),
                leading: const Icon(Icons.sports_soccer_outlined),
                title: Text(
                  '${item.playedAt.day.toString().padLeft(2, '0')}/'
                  '${item.playedAt.month.toString().padLeft(2, '0')} · '
                  '${item.playedAt.hour.toString().padLeft(2, '0')}:'
                  '${item.playedAt.minute.toString().padLeft(2, '0')}',
                ),
                subtitle: item.placeName == null ? null : Text(item.placeName!),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          ],
        ),
      ),
    );
    if (match == null) return;
    if (!mounted) return;
    final message = TextEditingController();
    final send = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Convidar ${player.name}',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text(
                  'A mensagem será exibida junto com os dados da partida.'),
              const SizedBox(height: 16),
              TextField(
                  controller: message,
                  maxLength: 500,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Mensagem (opcional)')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Enviar convite')),
            ]),
      ),
    );
    if (send != true) {
      message.dispose();
      return;
    }
    final text = message.text.trim();
    message.dispose();
    try {
      await _api.invite(groupId, match.id, player.id,
          openingId: widget.openingId, message: text.isEmpty ? null : text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
            content: Text('Não foi possível enviar o convite a '
                '${player.name}. Tente novamente.'),
          ));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _invited.add(player.id));
    final scheduled = '${match.playedAt.day.toString().padLeft(2, '0')}/'
        '${match.playedAt.month.toString().padLeft(2, '0')} às '
        '${match.playedAt.hour.toString().padLeft(2, '0')}:'
        '${match.playedAt.minute.toString().padLeft(2, '0')}';
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        content: Text('Convite enviado a ${player.name} para a partida de '
            '$scheduled. Agora ele precisa aceitar.'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasQuery = _query.text.trim().isNotEmpty;
    final isSearching = _waitingForDebounce || _loading;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _search,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 10),
              sliver: SliverToBoxAdapter(child: _header(context, colors)),
            ),
            if (hasQuery && isSearching)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (hasQuery && _error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _SearchState(
                  icon: Icons.cloud_off_outlined,
                  message: _error!,
                  action: OutlinedButton.icon(
                    onPressed: _search,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tentar novamente'),
                  ),
                ),
              )
            else if (hasQuery &&
                (_showGroups ? _groups.isEmpty : _players.isEmpty))
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _SearchState(
                  icon: Icons.search_off_rounded,
                  message: 'Nenhum perfil encontrado para essa busca.',
                ),
              )
            else if (hasQuery)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                sliver: _showGroups ? _groupList() : _playerList(colors),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, ColorScheme colors) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMUNIDADE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.7,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            widget.preferredMatchId == null
                ? 'Encontre sua próxima partida'
                : 'Buscar jogador para a vaga',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.7,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            widget.preferredMatchId == null
                ? 'Encontre patotas e jogadores do Patotas.'
                : 'Pesquise um perfil e envie um convite para esta partida.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          if (widget.preferredMatchId == null)
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SearchTab(
                      label: 'Patotas',
                      icon: Icons.groups_rounded,
                      selected: _showGroups,
                      onTap: () => _selectTab(true),
                    ),
                  ),
                  Expanded(
                    child: _SearchTab(
                      label: 'Jogadores',
                      icon: Icons.person_search_rounded,
                      selected: !_showGroups,
                      onTap: () => _selectTab(false),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _query,
            onChanged: _onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText:
                  _showGroups ? 'Nome ou código da patota' : 'Nome ou @usuário',
              filled: true,
              fillColor: colors.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _query.clear();
                        _onQueryChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ],
      );

  SliverList _groupList() => SliverList.separated(
        itemCount: _groups.length,
        itemBuilder: (_, index) {
          final group = _groups[index];
          return _GroupCard(
            item: group,
            onTap: () => context.push('/app/discover/groups/${group.id}'),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 10),
      );

  SliverList _playerList(ColorScheme colors) => SliverList.separated(
        itemCount: _players.length,
        itemBuilder: (_, index) {
          final player = _players[index];
          final account = ref.read(accountStoreProvider).activeAccount;
          final groupId = account?.activeGroupId;
          final canInvite = FeatureFlags.externalPlayerInteractionsEnabled &&
              groupId != null &&
              (account?.isGroupAdmin(groupId) ?? false) &&
              player.id != account?.userId &&
              !player.inGroup;
          return ListTile(
            onTap: () => context.push('/app/profile/${player.id}'),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: colors.outlineVariant),
            ),
            leading: AvatarWidget(
              name: player.name,
              photoUrl: player.photoUrl,
              size: 48,
              borderRadius: 15,
            ),
            title: Text(
              player.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '@${player.userName}'
              '${player.position == null ? '' : ' · ${player.position}'}',
            ),
            trailing: _invited.contains(player.id)
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle_rounded,
                        size: 18, color: colors.primary),
                    const SizedBox(width: 4),
                    Text('Convidado',
                        style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.w800)),
                  ])
                : player.inGroup
                    ? Text('Na patota',
                        style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w800))
                    : canInvite
                        ? FilledButton.tonal(
                            onPressed: () => _invite(player),
                            child: const Text('Convidar'),
                          )
                        : const Icon(Icons.chevron_right_rounded),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 9),
      );
}

class _SearchState extends StatelessWidget {
  const _SearchState({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              if (action != null) ...[
                const SizedBox(height: 16),
                action!,
              ],
            ],
          ),
        ),
      );
}

class _SearchTab extends StatelessWidget {
  const _SearchTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground =
        selected ? colors.onInverseSurface : colors.onSurfaceVariant;
    return Material(
      color: selected
          ? colors.inverseSurface
          : colors.surface.withValues(alpha: 0),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 7),
              Text(
                label,
                style:
                    TextStyle(fontWeight: FontWeight.w800, color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.item, required this.onTap});

  final DiscoveryGroupItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              _GroupLogo(item: item),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (item.isMember)
                          Text(
                            'SUA PATOTA',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: colors.primary,
                            ),
                          )
                        else if (!item.isPublic)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  size: 11,
                                  color: colors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'PRIVADA',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (item.accepting)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'COM VAGAS',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      item.code,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${item.city ?? 'Local não informado'} · '
                      '${item.members} jogadores',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupLogo extends StatelessWidget {
  const _GroupLogo({required this.item});

  final DiscoveryGroupItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = ColoredBox(
      color: colors.primaryContainer,
      child: Center(
        child: Text(
          item.name.trim().isEmpty ? '?' : item.name.trim()[0].toUpperCase(),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: colors.onPrimaryContainer,
          ),
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox.square(
        dimension: 58,
        child: item.logoUrl == null
            ? fallback
            : Image.network(
                item.logoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

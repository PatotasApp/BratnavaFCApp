import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/image_lightbox.dart';
import '../../data/discovery_datasource.dart';
import '../../domain/discovery_models.dart';

class DiscoveryGroupProfilePage extends ConsumerStatefulWidget {
  const DiscoveryGroupProfilePage({super.key, required this.groupId});
  final String groupId;
  @override
  ConsumerState<DiscoveryGroupProfilePage> createState() =>
      _DiscoveryGroupProfilePageState();
}

class _DiscoveryGroupProfilePageState
    extends ConsumerState<DiscoveryGroupProfilePage> {
  DiscoveryGroupProfile? data;
  bool loading = true;
  String? busy;
  DiscoveryDataSource get api => DiscoveryDataSource(ref.read(dioProvider));
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    try {
      final value = await api.group(widget.groupId);
      if (mounted) setState(() => data = value);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> apply(MatchOpening o) async {
    setState(() => busy = o.id);
    try {
      await api.apply(widget.groupId, o.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Candidatura enviada para o administrador.'),
          ),
        );
        await load();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível enviar a candidatura.'),
          ),
        );
    } finally {
      if (mounted) setState(() => busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final p = data;
    if (p == null)
      return const Scaffold(
        body: Center(child: Text('Patota não encontrada.')),
      );
    final account = ref.watch(accountStoreProvider).activeAccount;
    final isAdmin = account?.activeGroupId == widget.groupId &&
        (account?.isGroupAdmin(widget.groupId) ?? false);
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 230,
              pinned: true,
              stretch: true,
              title: Text(p.name),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [c.primary, c.tertiary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      bottom: 22,
                      child: GestureDetector(
                        onTap: p.logoUrl == null
                            ? null
                            : () => showImageLightbox(
                                  context,
                                  imageUrl: p.logoUrl!,
                                  heroTag: 'group-${p.id}',
                                ),
                        child: Hero(
                          tag: 'group-${p.id}',
                          child: _ProfileLogo(p: p),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
              sliver: SliverList.list(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Pill(icon: Icons.tag_rounded, text: p.code),
                      _Pill(
                        icon: Icons.groups_rounded,
                        text: '${p.members} jogadores',
                      ),
                      if (p.city != null)
                        _Pill(icon: Icons.location_on_outlined, text: p.city!),
                      if (p.accepting)
                        _Pill(
                          icon: Icons.sports_soccer_rounded,
                          text: 'Aceitando jogadores',
                          accent: true,
                        ),
                    ],
                  ),
                  if (p.description != null) ...[
                    const SizedBox(height: 18),
                    Text(
                      p.description!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.45),
                    ),
                  ],
                  if (p.accepting) ...[
                    const SizedBox(height: 26),
                    Text(
                      'PRÓXIMAS PARTIDAS',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: c.primary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                    ),
                    const SizedBox(height: 10),
                    if (p.matches.isEmpty)
                      _EmptyMatches()
                    else
                      ...p.matches.map(
                        (m) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _MatchCard(
                            match: m,
                            isAdmin: isAdmin,
                            busy: busy,
                            onApply: apply,
                            onManage: () => _manageOpening(m),
                            onDelete: (id) => _deleteOpening(id),
                          ),
                        ),
                      ),
                  ],
                  if (p.people.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text(
                      'INTEGRANTES',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                    ),
                    const SizedBox(height: 10),
                    ...p.people.map(
                      (x) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: AvatarWidget(
                          name: x.name,
                          photoUrl: x.photoUrl,
                          size: 44,
                          borderRadius: 14,
                        ),
                        title: Text(
                          x.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text('@${x.userName}'),
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

  Future<void> _manageOpening(DiscoveryMatch match) async {
    var slots = 1, position = 1;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            20 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Text(
                'Publicar vagas',
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat(
                  "EEEE, dd/MM 'às' HH:mm",
                  'pt_BR',
                ).format(match.playedAt),
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<int>(
                value: position,
                decoration: const InputDecoration(labelText: 'Preferência'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Qualquer posição')),
                  DropdownMenuItem(value: 2, child: Text('Linha')),
                  DropdownMenuItem(value: 3, child: Text('Goleiro')),
                ],
                onChanged: (v) => setModal(() => position = v ?? 1),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: '1',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantidade de vagas',
                ),
                onChanged: (v) => slots = int.tryParse(v) ?? 1,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Publicar vagas'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      await api.createOpening(widget.groupId, match.id, slots, position);
      await load();
    }
  }

  Future<void> _deleteOpening(String id) async {
    await api.deleteOpening(widget.groupId, id);
    await load();
  }
}

class _ProfileLogo extends StatelessWidget {
  const _ProfileLogo({required this.p});
  final DiscoveryGroupProfile p;
  @override
  Widget build(BuildContext context) => Container(
        width: 100,
        height: 100,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              blurRadius: 24,
              color:
                  Theme.of(context).colorScheme.shadow.withValues(alpha: .26),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: p.logoUrl != null
              ? Image.network(
                  p.logoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallback(context),
                )
              : _fallback(context),
        ),
      );
  Widget _fallback(BuildContext context) => ColoredBox(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Center(
          child: Text(
            p.name[0].toUpperCase(),
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
          ),
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, this.accent = false});
  final IconData icon;
  final String text;
  final bool accent;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: accent ? c.primaryContainer : c.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: accent ? c.onPrimaryContainer : c.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accent ? c.onPrimaryContainer : c.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.isAdmin,
    required this.busy,
    required this.onApply,
    required this.onManage,
    required this.onDelete,
  });
  final DiscoveryMatch match;
  final bool isAdmin;
  final String? busy;
  final ValueChanged<MatchOpening> onApply;
  final VoidCallback onManage;
  final ValueChanged<String> onDelete;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.outlineVariant),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: c.primaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: c.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat(
                        'EEEE, dd MMM',
                        'pt_BR',
                      ).format(match.playedAt),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${DateFormat('HH:mm').format(match.playedAt)} · ${match.placeName ?? 'Local liberado após aprovação'}',
                      style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (isAdmin)
                IconButton.filledTonal(
                  onPressed: onManage,
                  tooltip: 'Publicar vaga',
                  icon: const Icon(Icons.add_rounded),
                ),
            ],
          ),
          if (match.applicationStatus != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: c.tertiaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  'Sua candidatura está em andamento',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: c.onTertiaryContainer,
                  ),
                ),
              ),
            ),
          if (match.openings.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...match.openings.map(
              (o) => Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Row(
                  children: [
                    Icon(
                      o.position == 3
                          ? Icons.sports_soccer_rounded
                          : Icons.directions_run_rounded,
                      size: 18,
                      color: c.primary,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${o.available} ${o.available == 1 ? 'vaga' : 'vagas'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: c.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isAdmin)
                      IconButton(
                        onPressed: () => onDelete(o.id),
                        tooltip: 'Excluir vaga',
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    else
                      FilledButton.tonal(
                        onPressed:
                            match.applicationStatus != null || busy == o.id
                                ? null
                                : () => onApply(o),
                        child: busy == o.id
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Candidatar'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyMatches extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          children: [
            Icon(Icons.event_busy_outlined),
            SizedBox(height: 8),
            Text(
              'Nenhuma partida com vagas no momento.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

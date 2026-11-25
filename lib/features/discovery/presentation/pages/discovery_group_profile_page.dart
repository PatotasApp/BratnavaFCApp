import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/image_lightbox.dart';
import '../../data/discovery_datasource.dart';
import '../../domain/discovery_models.dart';

class DiscoveryGroupProfilePage extends ConsumerStatefulWidget {
  const DiscoveryGroupProfilePage({
    super.key,
    required this.groupId,
    this.groupName,
  });
  final String groupId;
  final String? groupName;
  @override
  ConsumerState<DiscoveryGroupProfilePage> createState() =>
      _DiscoveryGroupProfilePageState();
}

class _DiscoveryGroupProfilePageState
    extends ConsumerState<DiscoveryGroupProfilePage> {
  DiscoveryGroupProfile? data;
  bool loading = true;
  bool isPrivate = false;
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
    } on DioException catch (e) {
      // A API responde 404 tanto para patota inexistente quanto para privada.
      final msg = '${e.response?.data}'.toLowerCase();
      if (mounted && e.response?.statusCode == 404 && msg.contains('privada')) {
        setState(() => isPrivate = true);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> apply(DiscoveryMatch match) async {
    final controller = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
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
              Text('Solicitar para jogar',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(DateFormat("EEEE, dd/MM 'às' HH:mm", 'pt_BR')
                  .format(match.playedAt)),
              const SizedBox(height: 16),
              TextField(
                  controller: controller,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Mensagem (opcional)',
                      hintText:
                          'Conte um pouco sobre você ou sua disponibilidade')),
              const SizedBox(height: 8),
              FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.sports_soccer_rounded),
                  label: const Text('Enviar solicitação')),
            ]),
      ),
    );
    if (confirmed != true) {
      controller.dispose();
      return;
    }
    setState(() => busy = match.id);
    try {
      await api.apply(widget.groupId, match.id,
          message:
              controller.text.trim().isEmpty ? null : controller.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Candidatura enviada para o administrador.'),
          ),
        );
        await load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível enviar a candidatura.'),
          ),
        );
      }
    } finally {
      controller.dispose();
      if (mounted) setState(() => busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final p = data;
    if (p == null && isPrivate) {
      final c = Theme.of(context).colorScheme;
      return Scaffold(
        appBar: AppBar(title: Text(widget.groupName ?? 'Patota')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded,
                    size: 52, color: c.onSurfaceVariant),
                const SizedBox(height: 14),
                Text('Esta patota é privada',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(
                  'Só quem faz parte vê os detalhes. Para entrar, peça o '
                  'código ou o link a um administrador.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (p == null) {
      return const Scaffold(
        body: Center(child: Text('Patota não encontrada.')),
      );
    }
    final isOwnGroup =
        ref.watch(accountStoreProvider).activeAccount?.activeGroupId ==
            widget.groupId;
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
                      if (p.defaultDayOfWeek != null &&
                          p.defaultKickoffTime != null)
                        _Pill(
                          icon: Icons.schedule_rounded,
                          text: _scheduleLabel(p),
                        ),
                      if (p.accepting)
                        const _Pill(
                          icon: Icons.sports_soccer_rounded,
                          text: 'Aceitando jogadores',
                          accent: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _SectionLabel(text: 'SOBRE A PATOTA', color: c.primary),
                  const SizedBox(height: 10),
                  _AboutCard(profile: p),
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
                            canApply: !isOwnGroup,
                            busy: busy,
                            onApply: apply,
                          ),
                        ),
                      ),
                  ] else ...[
                    const SizedBox(height: 22),
                    _SectionLabel(text: 'NOVOS JOGADORES', color: c.primary),
                    const SizedBox(height: 10),
                    const _InfoCard(
                      icon: Icons.lock_clock_outlined,
                      text:
                          'Esta patota não está aceitando novos jogadores no momento.',
                    ),
                  ],
                  if (p.people.isNotEmpty || !p.showMembers) ...[
                    const SizedBox(height: 22),
                    const _SectionLabel(text: 'INTEGRANTES'),
                    const SizedBox(height: 10),
                    if (p.people.isEmpty)
                      const _InfoCard(
                        icon: Icons.visibility_off_outlined,
                        text: 'A lista de integrantes desta patota é privada.',
                      )
                    else
                      ...p.people.map(
                        (x) => ListTile(
                          onTap: () => context.push('/app/profile/${x.id}'),
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

  String _scheduleLabel(DiscoveryGroupProfile profile) {
    const days = [
      'Domingo',
      'Segunda',
      'Terça',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sábado',
    ];
    final day = profile.defaultDayOfWeek!;
    final time = profile.defaultKickoffTime!;
    final shortTime = time.length >= 5 ? time.substring(0, 5) : time;
    return '${day >= 0 && day < days.length ? days[day] : 'Dia definido'} às $shortTime';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
      );
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.profile});
  final DiscoveryGroupProfile profile;

  @override
  Widget build(BuildContext context) {
    final description = profile.description?.trim();
    final hasDescription = description != null && description.isNotEmpty;
    return _InfoCard(
      icon: Icons.groups_2_outlined,
      text: hasDescription
          ? description
          : 'Esta patota ainda não adicionou uma descrição ao perfil.',
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                height: 1.4,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
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
    required this.canApply,
    required this.busy,
    required this.onApply,
  });
  final DiscoveryMatch match;
  final bool canApply;
  final String? busy;
  final ValueChanged<DiscoveryMatch> onApply;
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
            ],
          ),
          if (match.participating || match.applicationStatus != null)
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
                  match.participating || match.applicationStatus == 3
                      ? 'Você foi aceito nessa partida'
                      : match.applicationStatus == 2
                          ? 'Você foi aprovado · confirme sua presença'
                          : 'Sua candidatura está em andamento',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: c.onTertiaryContainer,
                  ),
                ),
              ),
            ),
          if (match.applicationStatus == 2 && !match.participating) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.push('/app/guest-match/${match.id}'),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Confirmar presença'),
              ),
            ),
          ],
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
                  ],
                ),
              ),
            ),
          ],
          if (canApply &&
              !match.participating &&
              match.applicationStatus == null) ...[
            const SizedBox(height: 14),
            SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy == match.id ? null : () => onApply(match),
                  icon: busy == match.id
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sports_soccer_rounded),
                  label: const Text('Solicitar para jogar'),
                )),
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

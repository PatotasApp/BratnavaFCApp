import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/share/share_links.dart';
import '../../../shared/presentation/widgets/avatar_widget.dart';
import '../../auth/presentation/providers/account_store.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../dashboard/presentation/providers/dashboard_provider.dart';
import '../data/share_api.dart';

final shareApiProvider =
    Provider<ShareApi>((ref) => ShareApi(ref.watch(dioProvider)));

String _norm(String? id) =>
    (id ?? '').trim().toLowerCase().replaceAll(RegExp(r'[{}]'), '');

/// Deixa a patota do link como ativa antes de abrir a tela interna (as telas
/// leem a patota ativa). Mesmo caminho do toque em notificação.
Future<void> activateSharedGroup(WidgetRef ref, String groupId) async {
  final current = ref.read(accountStoreProvider).activeAccount?.activeGroupId;
  if (_norm(current) == _norm(groupId)) return;
  String? playerId;
  try {
    final players = await ref.read(myPlayersProvider.future);
    for (final p in players) {
      if (_norm(p.groupId) == _norm(groupId)) {
        playerId = p.playerId;
        break;
      }
    }
  } catch (_) {
    // Sem a lista ainda dá para abrir: as telas usam a patota ativa.
  }
  await ref
      .read(authNotifierProvider.notifier)
      .selectActiveGroup(groupId: groupId, playerId: playerId);
}

const _kindLabel = {
  ShareKind.match: 'Esta partida',
  ShareKind.mvp: 'Esta votação de MVP',
  ShareKind.championship: 'Este campeonato',
  ShareKind.poll: 'Esta enquete',
};

/// Tela aberta por link de partida, votação de MVP, campeonato ou enquete.
/// Integrante vai direto para a tela interna (que também checa na API); os
/// demais veem só o aviso.
class SharedContentLinkPage extends ConsumerStatefulWidget {
  final ShareKind kind;
  final String id;

  const SharedContentLinkPage(
      {super.key, required this.kind, required this.id});

  @override
  ConsumerState<SharedContentLinkPage> createState() =>
      _SharedContentLinkPageState();
}

class _SharedContentLinkPageState extends ConsumerState<SharedContentLinkPage> {
  late Future<ShareResolution?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ShareResolution?> _load() async {
    final result =
        await ref.read(shareApiProvider).resolve(widget.kind, widget.id);
    if (result != null && result.isMember && result.groupId != null) {
      await activateSharedGroup(ref, result.groupId!);
      if (mounted) context.go(internalRouteFor(result));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return _LinkScaffold(
      child: FutureBuilder<ShareResolution?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return LinkNotice(
              icon: Icons.wifi_off_rounded,
              title: 'Não foi possível abrir o link',
              message: extractDioError(snap.error),
              action: FilledButton(
                onPressed: () => setState(() => _future = _load()),
                child: const Text('Tentar de novo'),
              ),
            );
          }
          final r = snap.data;
          if (r == null) {
            return const LinkNotice(
              icon: Icons.link_off_rounded,
              title: 'Link não encontrado',
              message:
                  'O conteúdo pode ter sido removido ou o link está errado.',
            );
          }
          if (r.isMember) {
            return const Center(child: CircularProgressIndicator());
          }
          final of = r.groupName == null
              ? ' de uma patota'
              : ' da patota ${r.groupName}';
          return LinkNotice(
            logoUrl: r.groupLogoUrl,
            groupName: r.groupName,
            title: 'Só para integrantes',
            message:
                '${_kindLabel[widget.kind]} é$of, e só integrantes podem ver. '
                'Peça um convite a um administrador.',
          );
        },
      ),
    );
  }
}

/// Patota aberta por link: vitrine pública e, para integrante, o atalho.
class SharedGroupLinkPage extends ConsumerStatefulWidget {
  final String groupId;

  const SharedGroupLinkPage({super.key, required this.groupId});

  @override
  ConsumerState<SharedGroupLinkPage> createState() =>
      _SharedGroupLinkPageState();
}

class _SharedGroupLinkPageState extends ConsumerState<SharedGroupLinkPage> {
  late Future<PublicGroupResponse?> _future =
      ref.read(shareApiProvider).group(widget.groupId);
  bool _opening = false;

  Future<void> _open() async {
    setState(() => _opening = true);
    await activateSharedGroup(ref, widget.groupId);
    if (mounted) context.go('/app/groups');
  }

  @override
  Widget build(BuildContext context) {
    return _LinkScaffold(
      child: FutureBuilder<PublicGroupResponse?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return LinkNotice(
              icon: Icons.wifi_off_rounded,
              title: 'Não foi possível abrir o link',
              message: extractDioError(snap.error),
              action: FilledButton(
                onPressed: () => setState(() =>
                    _future = ref.read(shareApiProvider).group(widget.groupId)),
                child: const Text('Tentar de novo'),
              ),
            );
          }
          final data = snap.data;
          if (data == null) {
            return const LinkNotice(
              icon: Icons.link_off_rounded,
              title: 'Patota não encontrada',
              message: 'O link pode estar errado ou a patota foi encerrada.',
            );
          }
          final openButton = data.isMember
              ? FilledButton.icon(
                  onPressed: _opening ? null : _open,
                  icon: const Icon(Icons.groups_outlined),
                  label: const Text('Abrir a patota'),
                )
              : null;
          final g = data.group;
          if (!data.enabled || g == null) {
            return LinkNotice(
              title: 'Patota privada',
              message: data.isMember
                  ? 'A página pública desta patota está desligada, mas você é integrante.'
                  : 'Os administradores deixaram a página desta patota privada.',
              action: openButton,
            );
          }
          return _GroupShowcase(group: g, action: openButton);
        },
      ),
    );
  }
}

class _GroupShowcase extends StatelessWidget {
  final PublicGroup group;
  final Widget? action;

  const _GroupShowcase({required this.group, this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schedule = group.schedule;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: AvatarWidget(
            name: group.name,
            photoUrl: group.logoUrl,
            size: 88,
            fit: BoxFit.cover,
            borderRadius: 24,
          ),
        ),
        const SizedBox(height: 14),
        Text(group.name,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Desde ${group.sinceYear}',
            textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        const SizedBox(height: 20),
        Row(
          children: [
            _Stat(label: 'Integrantes', value: group.membersCount),
            _Stat(label: 'Jogos', value: group.matchesPlayed),
            _Stat(label: 'Gols', value: group.goalsScored),
          ],
        ),
        const SizedBox(height: 16),
        if (schedule != null)
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: Text(schedule),
            contentPadding: EdgeInsets.zero,
          ),
        if (group.placeName != null)
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(group.placeName!),
            contentPadding: EdgeInsets.zero,
          ),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text('$value',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900)),
                Text(label, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ),
      );
}

class _LinkScaffold extends StatelessWidget {
  final Widget child;

  const _LinkScaffold({required this.child});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('PatotasApp'),
          leading: IconButton(
            tooltip: 'Início',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.go('/app'),
          ),
        ),
        body: SafeArea(child: child),
      );
}

/// Aviso de "não dá para ver" das telas abertas por link.
class LinkNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? logoUrl;
  final String? groupName;
  final Widget? action;

  const LinkNotice({
    super.key,
    this.icon = Icons.lock_outline_rounded,
    required this.title,
    required this.message,
    this.logoUrl,
    this.groupName,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (logoUrl != null || groupName != null)
                AvatarWidget(
                  name: groupName ?? 'Patota',
                  photoUrl: logoUrl,
                  size: 64,
                  fit: BoxFit.cover,
                  borderRadius: 18,
                )
              else
                Icon(icon, size: 44),
              const SizedBox(height: 14),
              Text(title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: 18), action!],
            ],
          ),
        ),
      );
}

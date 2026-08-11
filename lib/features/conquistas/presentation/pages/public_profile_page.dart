import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../account/presentation/widgets/editable_profile_avatar.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../domain/entities/conquista_models.dart';
import '../providers/conquistas_provider.dart';
import '../widgets/conquistas_section.dart';
import '../../../../shared/presentation/widgets/app_page_header.dart';

class PublicProfilePage extends ConsumerWidget {
  final String userId;

  const PublicProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountStoreProvider).activeAccount;
    final isOwner = account?.userId == userId;

    return Scaffold(
      body: Column(
        children: [
          const AppPageHeader(
            title: 'Perfil',
            subtitle: 'Informações públicas do jogador',
            icon: Icons.person_outline_rounded,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(publicProfileProvider(userId));
                if (isOwner) ref.invalidate(profilePrivacyProvider);
              },
              child: ref.watch(publicProfileProvider(userId)).when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => ListView(
                      padding: const EdgeInsets.all(32),
                      children: [
                        Icon(
                          Icons.person_off_outlined,
                          size: 44,
                          color: context.appTextSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(extractDioError(error),
                            textAlign: TextAlign.center),
                      ],
                    ),
                    data: (profile) => _ProfileBody(
                      profile: profile,
                      isOwner: isOwner,
                      ownerEmail: isOwner ? account?.email : null,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final UserPublicProfile profile;
  final bool isOwner;
  final String? ownerEmail;

  const _ProfileBody({
    required this.profile,
    required this.isOwner,
    this.ownerEmail,
  });

  @override
  Widget build(BuildContext context) {
    final p = profile;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.appBorder),
          ),
          child: Column(
            children: [
              if (isOwner)
                EditableProfileAvatar(
                  userId: p.userId,
                  name: p.name,
                  photoUrl: p.photoUrl,
                  size: 84,
                  avatarBorderRadius: 26,
                )
              else
                AvatarWidget(
                  name: p.name,
                  photoUrl: p.photoUrl,
                  size: 84,
                  borderRadius: 26,
                ),
              const SizedBox(height: 14),
              Text(
                p.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
              ),
              if (p.userName.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  '@${p.userName}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                ),
              ],
              const SizedBox(height: 12),
              _PositionLabel(position: p.position),
              if (isOwner && (ownerEmail?.trim().isNotEmpty ?? false)) ...[
                const SizedBox(height: 6),
                Text(
                  ownerEmail!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appTextSecondary,
                      ),
                ),
              ],
              if (isOwner) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (sheetContext) => SafeArea(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
                        ),
                        child: const SingleChildScrollView(
                          child: _PrivacyCard(),
                        ),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.lock_outline_rounded, size: 17),
                  label: const Text('Privacidade do perfil'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Patotas',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        if (p.patotas.isEmpty)
          const _NoPatotasCard()
        else
          ...p.patotas.map(
            (patota) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PatotaCard(patota: patota),
            ),
          ),
      ],
    );
  }
}

class _PositionLabel extends StatelessWidget {
  final String? position;

  const _PositionLabel({required this.position});

  @override
  Widget build(BuildContext context) {
    final label = position?.trim().isNotEmpty == true
        ? position!.trim()
        : 'Posição não informada';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.sports_soccer_outlined,
            size: 16, color: context.appTextSecondary),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.appTextSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _NoPatotasCard extends StatelessWidget {
  const _NoPatotasCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.appBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.groups_outlined,
                color: context.appTextSecondary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Este jogador ainda não está em nenhuma patota.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.appTextSecondary,
                    ),
              ),
            ),
          ],
        ),
      );
}

class _PatotaCard extends StatelessWidget {
  final PatotaProfile patota;

  const _PatotaCard({required this.patota});

  @override
  Widget build(BuildContext context) {
    final achievements = topConquistas(patota.conquistas, 5);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.appSurfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.shield_outlined,
                    size: 19, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  patota.groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          if (achievements.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: achievements
                  .map((item) => _CompactAchievement(conquista: item))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactAchievement extends StatelessWidget {
  final Conquista conquista;

  const _CompactAchievement({required this.conquista});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: '${conquista.nome}\n${conquista.descricao}',
        triggerMode: TooltipTriggerMode.tap,
        showDuration: const Duration(seconds: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: context.appSurfaceSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.workspace_premium_outlined,
                  size: 15, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                conquista.nome,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      );
}

class _PrivacyCard extends ConsumerStatefulWidget {
  const _PrivacyCard();

  @override
  ConsumerState<_PrivacyCard> createState() => _PrivacyCardState();
}

class _PrivacyCardState extends ConsumerState<_PrivacyCard> {
  ProfilePrivacy? _draft;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return ref.watch(profilePrivacyProvider).when(
          loading: () => const _PrivacyShell(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => _PrivacyShell(
            child: Text(
              extractDioError(error),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          data: (privacy) {
            final current = _draft ?? privacy;
            return _PrivacyShell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Privacidade do perfil',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: current.visibility,
                    decoration:
                        const InputDecoration(labelText: 'Quem pode ver'),
                    items: const [
                      DropdownMenuItem(
                        value: 'AuthenticatedUsers',
                        child: Text('Todos no PatotasApp'),
                      ),
                      DropdownMenuItem(
                        value: 'SharedPatotas',
                        child: Text('Quem compartilha uma patota'),
                      ),
                      DropdownMenuItem(
                        value: 'Private',
                        child: Text('Somente eu'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(
                          () => _draft = current.copyWith(visibility: value));
                    },
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mostrar nomes das patotas'),
                    value: current.showPatotaNames,
                    onChanged: (value) => setState(
                      () => _draft = current.copyWith(showPatotaNames: value),
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mostrar conquistas de zoeira'),
                    subtitle: const Text('Inclui feitos como gols contra.'),
                    value: current.showZoeiraAchievements,
                    onChanged: (value) => setState(
                      () => _draft = current.copyWith(
                        showZoeiraAchievements: value,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() => _saving = true);
                              try {
                                final saved =
                                    await saveProfilePrivacy(ref, current);
                                if (!mounted) return;
                                setState(() => _draft = saved);
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Privacidade atualizada.'),
                                  ),
                                );
                              } catch (error) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                      content: Text(extractDioError(error))),
                                );
                              } finally {
                                if (mounted) setState(() => _saving = false);
                              }
                            },
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_outline_rounded),
                      label: const Text('Salvar privacidade'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
  }
}

class _PrivacyShell extends StatelessWidget {
  final Widget child;

  const _PrivacyShell({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.appBorder),
        ),
        child: child,
      );
}

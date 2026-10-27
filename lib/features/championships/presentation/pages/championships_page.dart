import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/app_page_header.dart';
import '../../../../shared/presentation/widgets/no_active_group_view.dart';
import '../../../../shared/presentation/widgets/prototype_ui.dart';
import '../../domain/entities/championship_enums.dart';
import '../../domain/entities/championship_models.dart';
import '../championship_ui_text.dart';
import '../providers/championship_provider.dart';

class ChampionshipsPage extends ConsumerWidget {
  const ChampionshipsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupId = ref.watch(championshipGroupIdProvider);
    final isAdmin = ref.watch(championshipIsAdminProvider);
    final state = ref.watch(championshipListProvider);

    return Column(
      children: [
        AppPageHeader.main(
          title: 'Campeonatos',
          subtitle: 'Torneios da patota em um só lugar',
          icon: Icons.emoji_events_outlined,
          actions: [
            if (isAdmin)
              AppPageHeaderAction(
                icon: Icons.add_rounded,
                tooltip: 'Criar campeonato',
                onPressed: () => context.push('/app/championships/new'),
              ),
          ],
        ),
        Expanded(
          child: groupId.isEmpty
              ? const NoActiveGroupView()
              : _ChampionshipListBody(state: state, isAdmin: isAdmin),
        ),
      ],
    );
  }
}

class _ChampionshipListBody extends ConsumerWidget {
  const _ChampionshipListBody({required this.state, required this.isAdmin});

  final ChampionshipListState state;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return PrototypeScrollView(
      onRefresh: ref.read(championshipListProvider.notifier).load,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.error != null) ...[
            PrototypeCard(
              color: context.appDangerContainer,
              borderColor: context.appDanger,
              child: Text(state.error!),
            ),
            const SizedBox(height: 12),
          ],
          PrototypeSectionTitle(
            title: 'Campeonatos da patota',
            count: '${state.items.length}',
          ),
          const SizedBox(height: 12),
          if (state.items.isEmpty)
            PrototypeCard(
              child: Column(
                children: [
                  const Icon(Icons.emoji_events_outlined, size: 38),
                  const SizedBox(height: 10),
                  Text(
                    'Nenhum campeonato ainda',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => context.push('/app/championships/new'),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Criar campeonato'),
                    ),
                  ],
                ],
              ),
            )
          else
            for (final item in state.items) ...[
              _ChampionshipCard(item: item),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _ChampionshipCard extends StatelessWidget {
  const _ChampionshipCard({required this.item});
  final ChampionshipSummary item;

  @override
  Widget build(BuildContext context) {
    final date =
        DateFormat("dd 'de' MMM · HH:mm", 'pt_BR').format(item.playedAt);
    final tone = switch (item.status) {
      ChampionshipStatus.inProgress => PrototypeBadgeTone.accent,
      ChampionshipStatus.finalized => PrototypeBadgeTone.success,
      ChampionshipStatus.cancelled => PrototypeBadgeTone.danger,
      _ => PrototypeBadgeTone.neutral,
    };

    return PrototypeCard(
      onTap: () => context.push('/app/championships/${item.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.appSurfaceSubtle,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.emoji_events_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text('$date · ${item.placeName}'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PrototypeBadge(
                label: championshipStatusLabel(item.status),
                tone: tone,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('${item.teamCount} times · ${item.gameCount} jogos'),
          if (item.championTeamName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.workspace_premium,
                    size: 18, color: context.appWarning),
                const SizedBox(width: 6),
                Text('Campeão: ${item.championTeamName}'),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final badge in item.ruleBadges) PrototypeBadge(label: badge),
            ],
          ),
        ],
      ),
    );
  }
}

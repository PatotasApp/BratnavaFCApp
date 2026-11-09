import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/app_page_header.dart';
import '../../../../shared/presentation/widgets/no_active_group_view.dart';
import '../../domain/season_models.dart';
import '../providers/seasons_provider.dart';

const _medals = ['🥇', '🥈', '🥉'];
final _fmt = DateFormat('dd/MM/yyyy');

/// Retrospectiva da temporada encerrada: campeões de cada categoria e a
/// classificação real, sem o "top x%" de durante a temporada.
class SeasonSummaryPage extends ConsumerStatefulWidget {
  final String seasonId;
  const SeasonSummaryPage({super.key, required this.seasonId});

  @override
  ConsumerState<SeasonSummaryPage> createState() => _SeasonSummaryPageState();
}

class _SeasonSummaryPageState extends ConsumerState<SeasonSummaryPage> {
  final _cardKey = GlobalKey();

  Future<void> _shareImage(SeasonSummary data) async {
    try {
      final boundary = _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      await Share.shareXFiles(
        [XFile.fromData(bytes.buffer.asUint8List(), mimeType: 'image/png', name: 'temporada.png')],
        text: _shareText(data),
      );
    } catch (_) {
      await Share.share(_shareText(data));
    }
  }

  String _shareText(SeasonSummary data) {
    final champions = data.rankings
        .where((r) => r.rows.isNotEmpty)
        .map((r) => '${r.icon} ${r.name}: ${r.rows.where((row) => row.position == 1).map((row) => '${row.playerName} (${r.format(row.value)})').join(', ')}')
        .join('\n');
    return 'Temporada ${data.season.displayName} encerrada!\n$champions';
  }

  @override
  Widget build(BuildContext context) {
    final groupId = ref.watch(seasonsGroupIdProvider);
    return Scaffold(
      body: Column(
        children: [
          AppPageHeader(
            title: 'Retrospectiva',
            subtitle: 'Campeões e classificação da temporada',
            icon: Icons.emoji_events_outlined,
            onBack: () => context.canPop() ? context.pop() : context.go('/app/conquistas'),
          ),
          Expanded(
            child: groupId.isEmpty
                ? const NoActiveGroupView(message: 'Selecione uma patota.')
                : ref.watch(seasonSummaryProvider((groupId: groupId, seasonId: widget.seasonId))).when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                        child: Padding(padding: const EdgeInsets.all(24), child: Text(extractDioError(e))),
                      ),
                      data: (data) => _body(context, data),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, SeasonSummary data) {
    final season = data.season;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
      children: [
        RepaintBoundary(
          key: _cardKey,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(colors: [AppColors.slate900, AppColors.slate800]),
            ),
            child: DefaultTextStyle(
              style: const TextStyle(color: AppColors.onDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('RETROSPECTIVA', style: TextStyle(fontSize: 11, color: AppColors.slate400, letterSpacing: 1.5)),
                  Text('Temporada ${season.displayName}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  Text(
                    '${_fmt.format(season.startsAt.toLocal())} → ${season.endsAt == null ? '…' : _fmt.format(season.endsAt!.toLocal())}'
                    '${season.isPreSeason ? ' · pré-temporada' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.slate400),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Total('Partidas', data.matches),
                      _Total('Campeonatos', data.championships),
                      _Total('Gols', data.goals),
                      _Total('Jogadores', data.players),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final ranking in data.rankings.where((r) => r.rows.isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${ranking.icon} ${ranking.name}: ${ranking.rows.where((row) => row.position == 1).map((row) => '🥇 ${row.playerName} · ${ranking.format(row.value)}').join('  ')}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _shareImage(data),
            icon: const Icon(Icons.share_outlined),
            label: const Text('Compartilhar'),
          ),
        ),
        if (season.isPreSeason)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Pré-temporada não gera títulos: a classificação abaixo é só para conferir.'),
          )
        else if (!data.titlesSealed)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Os títulos saem quando a temporada tem pelo menos 4 jogadores com jogos.'),
          ),
        const SizedBox(height: 8),
        for (final ranking in data.rankings) _RankingCard(ranking: ranking),
      ],
    );
  }
}

class _Total extends StatelessWidget {
  final String label;
  final int value;
  const _Total(this.label, this.value);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: AppColors.onDark.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.slate400)),
            Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.onDark)),
          ],
        ),
      );
}

/// Pódio e, ao abrir, a classificação completa com a posição real.
class _RankingCard extends StatefulWidget {
  final SeasonRanking ranking;
  const _RankingCard({required this.ranking});

  @override
  State<_RankingCard> createState() => _RankingCardState();
}

class _RankingCardState extends State<_RankingCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final ranking = widget.ranking;
    final podium = ranking.rows.where((r) => r.position <= 3).toList();
    final rest = ranking.rows.where((r) => r.position > 3).toList();
    final shown = [...podium, if (_open) ...rest];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${ranking.icon} ', style: const TextStyle(fontSize: 18)),
                Expanded(child: Text(ranking.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                if (ranking.minGames > 0)
                  Text('mín. ${ranking.minGames} jogos', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            if (ranking.rows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Ninguém nesta categoria.', style: Theme.of(context).textTheme.bodySmall),
              ),
            for (final row in shown)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: SizedBox(
                  width: 36,
                  child: Center(child: Text(row.position <= 3 ? _medals[row.position - 1] : '${row.position}º')),
                ),
                title: Text('${row.playerName}${row.isGuest ? ' · convidado' : ''}', overflow: TextOverflow.ellipsis),
                trailing: Text('${row.games} j   ${ranking.format(row.value)}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            if (rest.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _open = !_open),
                child: Text(_open ? 'Mostrar só o pódio' : 'Classificação completa (${ranking.rows.length})'),
              ),
          ],
        ),
      ),
    );
  }
}

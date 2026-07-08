import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../domain/entities/replay_clip.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/presentation/widgets/confirm_dialog.dart';
import '../providers/replays_provider.dart';
import 'replay_video_player_page.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

class ReplayVaultPage extends ConsumerStatefulWidget {
  const ReplayVaultPage({super.key});

  @override
  ConsumerState<ReplayVaultPage> createState() => _ReplayVaultPageState();
}

class _ReplayVaultPageState extends ConsumerState<ReplayVaultPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// matchIds that the user explicitly expanded. Matches start collapsed.
  final Set<String> _expandedMatches = {};

  // ── Account helpers ───────────────────────────────────────────────────────

  bool _resolvedIsAdmin(String groupId) {
    final acc = ref.read(accountStoreProvider).activeAccount;
    if (acc == null) return false;
    return acc.isGroupAdmin(groupId);
  }

  String? get _accessToken =>
      ref.read(accountStoreProvider).activeAccount?.accessToken;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Grouping ──────────────────────────────────────────────────────────────

  Map<String, List<ReplayClip>> _groupByMatch(List<ReplayClip> clips) {
    final result = <String, List<ReplayClip>>{};
    for (final clip in clips) {
      (result[clip.matchId] ??= []).add(clip);
    }
    return result;
  }

  DateTime _matchDate(List<ReplayClip> clips) {
    DateTime? latest;
    for (final clip in clips) {
      final parsed = DateTime.tryParse(clip.matchDate);
      if (parsed == null) continue;
      if (latest == null || parsed.isAfter(latest)) latest = parsed;
    }
    return latest ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _toggleMatch(String matchId) => setState(() {
        if (_expandedMatches.contains(matchId)) {
          _expandedMatches.remove(matchId);
        } else {
          _expandedMatches.add(matchId);
        }
      });

  // ── Delete confirmation ───────────────────────────────────────────────────

  Future<void> _confirmDelete(
    ReplayListNotifier notifier,
    ReplayClip clip,
  ) async {
    final ok = await showConfirmDialog(
      context: context,
      title: 'Excluir replay',
      message: 'Excluir o replay da partida em ${clip.matchPlace}?',
      confirmLabel: 'Excluir',
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await notifier.deleteClip(clip.clipId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Replay excluído.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(extractDioError(e, 'Erro ao excluir replay.'))),
        );
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Tab content ───────────────────────────────────────────────────────────

  Widget _buildTabContent({
    required AsyncValue<List<ReplayClip>> state,
    required ReplayListNotifier notifier,
    required bool adminOnly,
    required bool isAdmin,
    required String groupId,
    required String? accessToken,
  }) {
    if (adminOnly && !isAdmin) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Apenas administradores podem ver todos os replays.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: Colors.grey),
              const SizedBox(height: 12),
              Text('Erro ao carregar: $err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: notifier.fetch,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
      data: (clips) {
        if (clips.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_off_outlined,
                      size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Nenhum replay disponível.',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        final groups = _groupByMatch(clips).entries.toList()
          ..sort((a, b) => _matchDate(b.value).compareTo(_matchDate(a.value)));
        final slivers = <Widget>[];

        for (final entry in groups) {
          final matchId = entry.key;
          final matchClips = entry.value;
          final collapsed = !_expandedMatches.contains(matchId);

          // ── Group header ──────────────────────────────────────────────
          slivers.add(SliverToBoxAdapter(
            child: _MatchSectionHeader(
              matchClips: matchClips,
              collapsed: collapsed,
              onToggle: () => _toggleMatch(matchId),
            ),
          ));

          // ── Clip grid (hidden when collapsed) ─────────────────────────
          if (!collapsed) {
            slivers.add(SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  mainAxisExtent: 168,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final clip = matchClips[i];
                    return _GridClipCard(
                      clip: clip,
                      isAdmin: isAdmin,
                      onTap: () {
                        if (groupId.isEmpty) return;
                        Navigator.of(context).push(MaterialPageRoute<void>(
                          fullscreenDialog: true,
                          builder: (_) => ReplayVideoPlayerPage(
                            clips: matchClips,
                            initialIndex: i,
                            groupId: groupId,
                            accessToken: accessToken,
                          ),
                        ));
                      },
                      onLike: () async {
                        try {
                          await notifier.toggleLike(clip.clipId);
                        } catch (e) {
                          _showError(
                              extractDioError(e, 'Erro ao curtir replay.'));
                        }
                      },
                      onFavorite: () async {
                        try {
                          await notifier.toggleFavorite(clip.clipId);
                        } catch (e) {
                          _showError(
                              extractDioError(e, 'Erro ao favoritar replay.'));
                        }
                      },
                      onDelete:
                          isAdmin ? () => _confirmDelete(notifier, clip) : null,
                    );
                  },
                  childCount: matchClips.length,
                ),
              ),
            ));
          }
        }

        // ── Load-more (paginação) ─────────────────────────────────────────
        if (notifier.hasMore) {
          slivers.add(SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: notifier.isLoadingMore
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : TextButton.icon(
                        onPressed: () => notifier.fetchNext(),
                        icon: const Icon(Icons.expand_more_rounded, size: 18),
                        label: Text(
                            'Carregar mais (${notifier.total - clips.length})'),
                      ),
              ),
            ),
          ));
        }

        // bottom padding
        slivers.add(const SliverPadding(
          padding: EdgeInsets.only(bottom: 32),
        ));

        return RefreshIndicator(
          onRefresh: notifier.fetch,
          child: NotificationListener<ScrollNotification>(
            onNotification: (sn) {
              if (sn.metrics.pixels >= sn.metrics.maxScrollExtent - 400 &&
                  notifier.hasMore &&
                  !notifier.isLoadingMore) {
                notifier.fetchNext();
              }
              return false;
            },
            child: CustomScrollView(slivers: slivers),
          ),
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    final gid = account?.activeGroupId ?? activePlayer?.groupId ?? '';
    final isAdmin = _resolvedIsAdmin(gid);
    final accessToken = _accessToken;

    final playersAsync = ref.watch(myPlayersProvider);
    if (gid.isEmpty && playersAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (gid.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_outlined,
                  size: 44,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white24
                      : Colors.black26),
              const SizedBox(height: 12),
              const Text(
                'Crie ou entre em um grupo',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final allState = ref.watch(replaysAllProvider(gid));
    final likedState = ref.watch(replaysLikedProvider(gid));
    final favoritesState = ref.watch(replaysFavoritesProvider(gid));

    final allNotifier = ref.read(replaysAllProvider(gid).notifier);
    final likedNotifier = ref.read(replaysLikedProvider(gid).notifier);
    final favoritesNotifier = ref.read(replaysFavoritesProvider(gid).notifier);

    return Scaffold(
      body: Column(
        children: [
          _ReplayHeader(tabController: _tabController),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTabContent(
                  state: allState,
                  notifier: allNotifier,
                  adminOnly: true,
                  isAdmin: isAdmin,
                  groupId: gid,
                  accessToken: accessToken,
                ),
                _buildTabContent(
                  state: likedState,
                  notifier: likedNotifier,
                  adminOnly: false,
                  isAdmin: isAdmin,
                  groupId: gid,
                  accessToken: accessToken,
                ),
                _buildTabContent(
                  state: favoritesState,
                  notifier: favoritesNotifier,
                  adminOnly: false,
                  isAdmin: isAdmin,
                  groupId: gid,
                  accessToken: accessToken,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grid clip card ────────────────────────────────────────────────────────────

class _GridClipCard extends StatelessWidget {
  final ReplayClip clip;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onFavorite;
  final VoidCallback? onDelete;

  const _GridClipCard({
    required this.clip,
    required this.isAdmin,
    required this.onTap,
    required this.onLike,
    required this.onFavorite,
    this.onDelete,
  });

  String get _eventEmoji {
    switch ((clip.eventType ?? '').toLowerCase()) {
      case 'gol':
        return '⚽';
      case 'defesa':
        return '🧤';
      case 'falta':
        return '🟨';
      default:
        return '🎬';
    }
  }

  String get _eventLabel {
    if (clip.scorerName != null) {
      final assist = clip.assistName != null ? ' (${clip.assistName})' : '';
      return '${clip.scorerName}$assist';
    }
    if (clip.eventType != null) return clip.eventType!;
    return '';
  }

  String get _formattedDate {
    try {
      final dt = AppDateUtils.parseOrNow(clip.matchDate);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return clip.matchDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? Colors.white54 : const Color(0xFF64748B);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Thumbnail ───────────────────────────────────────────────
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(9)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: const Color(0xFF0F172A)),
                    Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white30),
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            size: 20, color: Colors.white),
                      ),
                    ),
                    if (clip.minute != null)
                      Positioned(
                        right: 5,
                        bottom: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .65),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${clip.minute}'",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Info ────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_formattedDate · ${clip.matchPlace}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (_eventLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$_eventEmoji $_eventLabel',
                        style: TextStyle(fontSize: 10, color: textSub),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Actions ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: Row(
                children: [
                  _MiniAction(
                    icon: clip.isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: clip.isLiked ? Colors.redAccent : textSub,
                    label: clip.likeCount > 0 ? '${clip.likeCount}' : null,
                    onTap: onLike,
                  ),
                  _MiniAction(
                    icon: clip.isFavorited
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: clip.isFavorited ? Colors.amber : textSub,
                    onTap: onFavorite,
                  ),
                  const Spacer(),
                  if (isAdmin && onDelete != null)
                    _MiniAction(
                      icon: Icons.delete_outline_rounded,
                      color: Colors.redAccent.withValues(alpha: .7),
                      onTap: onDelete!,
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

class _MiniAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? label;
  final VoidCallback onTap;

  const _MiniAction({
    required this.icon,
    required this.color,
    this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            if (label != null) ...[
              const SizedBox(width: 2),
              Text(label!, style: TextStyle(fontSize: 10, color: color)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Match section header ──────────────────────────────────────────────────────

class _MatchSectionHeader extends StatelessWidget {
  final List<ReplayClip> matchClips;
  final bool collapsed;
  final VoidCallback onToggle;

  const _MatchSectionHeader({
    required this.matchClips,
    required this.collapsed,
    required this.onToggle,
  });

  String get _formattedDate {
    try {
      final dt = AppDateUtils.parseOrNow(matchClips.first.matchDate);
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      return '$d/$m/${dt.year}';
    } catch (_) {
      return matchClips.first.matchDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? Colors.white54 : Colors.black45;
    final n = matchClips.length;

    final radius = collapsed
        ? BorderRadius.circular(10)
        : const BorderRadius.vertical(top: Radius.circular(10));

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.only(top: 10, left: 12, right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(color: bgColor, borderRadius: radius),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: .15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.sports_soccer_rounded,
                  size: 15, color: Color(0xFF3B82F6)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_formattedDate · ${matchClips.first.matchPlace}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$n ${n == 1 ? "vídeo" : "vídeos"}',
                    style: TextStyle(fontSize: 11, color: subColor),
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns: collapsed ? -0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  size: 22, color: subColor),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Page header ───────────────────────────────────────────────────────────────

class _ReplayHeader extends StatelessWidget {
  final TabController tabController;
  const _ReplayHeader({required this.tabController});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.white.withValues(alpha: .2)),
                    ),
                    child: const Icon(Icons.videocam_rounded,
                        size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Replay Vault',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Seus melhores momentos',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 2,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
                tabs: const [
                  Tab(text: 'Todos'),
                  Tab(text: 'Curtidos'),
                  Tab(text: 'Favoritos'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

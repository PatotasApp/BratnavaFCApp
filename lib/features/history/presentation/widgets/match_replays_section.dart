import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../replays/domain/entities/replay_clip.dart';
import '../../../replays/presentation/pages/replay_video_player_page.dart';

/// Vídeos da partida: faixa de miniaturas com filtro (todos, gols, jogadas) e o
/// player em tela cheia. Compartilhado com os jogos do campeonato, que mostram
/// os vídeos do mesmo jeito.

// ── Replays section ───────────────────────────────────────────────────────────

// ── Replays section — strip horizontal compacta ───────────────────────────────
//
// Com até 60 clips por jogo, usar uma lista vertical de cards grandes seria
// inviável. A strip horizontal mantém a seção com altura fixa (≈130 px) e
// deixa o usuário fazer scroll lateral para ver todos os clips.

class MatchReplaysSection extends StatefulWidget {
  final List<ReplayClip> replays;
  final String groupId;
  final String? accessToken;
  final bool isDark;

  const MatchReplaysSection({
    super.key,
    required this.replays,
    required this.groupId,
    required this.accessToken,
    required this.isDark,
  });

  @override
  State<MatchReplaysSection> createState() => MatchReplaysSectionState();
}

enum _ReplayFilter { all, goals, plays }

class MatchReplaysSectionState extends State<MatchReplaysSection> {
  static const _pageSize = 12;
  _ReplayFilter _filter = _ReplayFilter.all;
  int _page = 1;

  bool _isGoalClip(ReplayClip clip) {
    final type = (clip.eventType ?? '').toLowerCase();
    return type.contains('gol') || type.contains('goal');
  }

  List<ReplayClip> get _filtered {
    return widget.replays.where((clip) {
      final isGoal = _isGoalClip(clip);
      return switch (_filter) {
        _ReplayFilter.all => true,
        _ReplayFilter.goals => isGoal,
        _ReplayFilter.plays => !isGoal,
      };
    }).toList();
  }

  int get _goalCount => widget.replays.where(_isGoalClip).length;
  int get _playCount => widget.replays.length - _goalCount;

  void _setFilter(_ReplayFilter filter) {
    if (_filter == filter) return;
    setState(() {
      _filter = filter;
      _page = 1;
    });
  }

  void _openPlayer(BuildContext context, ReplayClip clip) {
    final index = widget.replays.indexWhere((r) => r.clipId == clip.clipId);
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ReplayVideoPlayerPage(
        clips: widget.replays,
        initialIndex: index < 0 ? 0 : index,
        groupId: widget.groupId,
        accessToken: widget.accessToken,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final totalPages = (filtered.length / _pageSize).ceil().clamp(1, 999);
    final safePage = _page.clamp(1, totalPages);
    final start = (safePage - 1) * _pageSize;
    final pageItems = filtered.skip(start).take(_pageSize).toList();
    final rangeStart = filtered.isEmpty ? 0 : start + 1;
    final rangeEnd = (start + pageItems.length).clamp(0, filtered.length);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isDark ? AppColors.slate900 : AppColors.onDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isDark ? AppColors.slate700 : AppColors.slate200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Replays (${widget.replays.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: widget.isDark ? AppColors.onDark : AppColors.slate900,
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ReplayFilterButton(
                    label: 'Todos',
                    count: widget.replays.length,
                    active: _filter == _ReplayFilter.all,
                    isDark: widget.isDark,
                    onTap: () => _setFilter(_ReplayFilter.all),
                  ),
                  const SizedBox(width: 8),
                  _ReplayFilterButton(
                    label: 'Gols',
                    count: _goalCount,
                    active: _filter == _ReplayFilter.goals,
                    isDark: widget.isDark,
                    onTap: () => _setFilter(_ReplayFilter.goals),
                  ),
                  const SizedBox(width: 8),
                  _ReplayFilterButton(
                    label: 'Jogadas',
                    count: _playCount,
                    active: _filter == _ReplayFilter.plays,
                    isDark: widget.isDark,
                    onTap: () => _setFilter(_ReplayFilter.plays),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Nenhum replay encontrado.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        widget.isDark ? AppColors.slate500 : AppColors.slate400,
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = (constraints.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final entry in pageItems.indexed)
                        SizedBox(
                          width: itemWidth,
                          child: _ReplayTile(
                            clip: entry.$2,
                            index: start + entry.$1 + 1,
                            hasUrl: resolveClipUrl(
                                  entry.$2,
                                  widget.groupId,
                                  widget.accessToken,
                                ) !=
                                null,
                            videoUrl: resolveClipUrl(
                              entry.$2,
                              widget.groupId,
                              widget.accessToken,
                            ),
                            isDark: widget.isDark,
                            onTap: () => _openPlayer(context, entry.$2),
                          ),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed:
                      safePage <= 1 ? null : () => setState(() => _page--),
                  icon: const Icon(Icons.chevron_left_rounded, size: 16),
                  label: const Text('Anterior'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
                Expanded(
                  child: Text(
                    '$rangeStart-$rangeEnd de ${filtered.length}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isDark
                          ? AppColors.slate400
                          : AppColors.slate500,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: safePage >= totalPages
                      ? null
                      : () => setState(() => _page++),
                  label: const Text('Próxima'),
                  icon: const Icon(Icons.chevron_right_rounded, size: 16),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplayFilterButton extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;

  const _ReplayFilterButton({
    required this.label,
    required this.count,
    required this.active,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active
        ? AppColors.onDark
        : (isDark ? AppColors.slate300 : AppColors.slate600);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? AppColors.slate900
              : (isDark ? AppColors.slate800 : AppColors.slate50),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? AppColors.slate900
                : (isDark ? AppColors.slate700 : AppColors.slate100),
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.darkApp.withAlpha(45),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.onDark.withAlpha(35)
                    : (isDark ? AppColors.slate700 : AppColors.slate100),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: active
                      ? AppColors.onDark
                      : (isDark ? AppColors.slate300 : AppColors.slate500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplayTile extends StatelessWidget {
  final ReplayClip clip;
  final int index;
  final bool hasUrl;
  final String? videoUrl;
  final bool isDark;
  final VoidCallback? onTap;

  const _ReplayTile({
    required this.clip,
    required this.index,
    required this.hasUrl,
    required this.videoUrl,
    required this.isDark,
    this.onTap,
  });

  bool get _isGoal {
    final t = clip.eventType?.toLowerCase() ?? '';
    return t.contains('gol') || t.contains('goal');
  }

  String get _label => _isGoal ? 'GOL' : 'JOGADA';

  @override
  Widget build(BuildContext context) {
    final badgeColor = _isGoal ? AppColors.accent : AppColors.info;

    return AspectRatio(
      aspectRatio: 1.65,
      child: Material(
        color: AppColors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: hasUrl ? onTap : null,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkApp.withAlpha(55),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.darkBorder,
                          AppColors.darkCard,
                          AppColors.darkApp,
                        ],
                      ),
                    ),
                    child: CustomPaint(painter: _ReplayPitchPainter()),
                  ),
                  if (videoUrl != null) _ReplayVideoThumb(url: videoUrl!),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.darkApp.withAlpha(18),
                          AppColors.transparent,
                          AppColors.darkApp.withAlpha(210),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.onDark.withAlpha(hasUrl ? 52 : 24),
                        border: Border.all(
                          color: AppColors.onDark.withAlpha(hasUrl ? 88 : 38),
                        ),
                      ),
                      child: Icon(
                        hasUrl
                            ? Icons.play_arrow_rounded
                            : Icons.videocam_off_rounded,
                        size: 25,
                        color: AppColors.onDark.withAlpha(hasUrl ? 230 : 90),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 7,
                    left: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _label,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.onDark,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 7,
                    right: 7,
                    child: Text(
                      '#$index',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.onDark70,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 7,
                    child: Row(
                      children: [
                        Icon(
                          clip.isLiked
                              ? Icons.favorite
                              : Icons.favorite_border_rounded,
                          size: 13,
                          color: AppColors.onDark70,
                        ),
                        if (clip.likeCount > 0) ...[
                          const SizedBox(width: 2),
                          Text('${clip.likeCount}',
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.onDark70)),
                        ],
                        const SizedBox(width: 7),
                        Icon(
                          clip.isFavorited
                              ? Icons.bookmark
                              : Icons.bookmark_border_rounded,
                          size: 13,
                          color: AppColors.onDark70,
                        ),
                        const Spacer(),
                        Text(
                          _timeLabel(clip),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onDark70,
                          ),
                        ),
                        const SizedBox(width: 7),
                        const _MiniReplayIcon(icon: Icons.link_rounded),
                        const SizedBox(width: 5),
                        const _MiniReplayIcon(icon: Icons.download_rounded),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _timeLabel(ReplayClip clip) {
    if (clip.minute != null) return "${clip.minute}'";
    final date = AppDateUtils.parse(clip.createdAt);
    if (date == null) return '--:--';
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}:'
        '${date.second.toString().padLeft(2, '0')}';
  }
}

class _MiniReplayIcon extends StatelessWidget {
  final IconData icon;
  const _MiniReplayIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: AppColors.darkApp.withAlpha(130),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Icon(icon, size: 11, color: AppColors.onDark70),
    );
  }
}

class _ReplayVideoThumb extends StatefulWidget {
  final String url;

  const _ReplayVideoThumb({required this.url});

  @override
  State<_ReplayVideoThumb> createState() => _ReplayVideoThumbState();
}

/// Miniatura feita com um player parado num quadro do vídeo. Cada player segura
/// um decodificador de 2560×720 e dezenas de MB; com vários abertos o Android
/// encerra o app por falta de memória. Por isso: no máximo [_maxLiveControllers]
/// ao mesmo tempo, só para as miniaturas que estão na tela, e o player é
/// liberado quando a miniatura sai da tela (as que estão esperando assumem a vaga).
class _ReplayVideoThumbState extends State<_ReplayVideoThumb> {
  static const int _maxLiveControllers = 2;
  static int _liveControllers = 0;

  /// Avisa as miniaturas que ficaram esperando quando uma vaga é liberada.
  static final ValueNotifier<int> _slotReleased = ValueNotifier(0);

  VideoPlayerController? _controller;
  bool _ready = false;
  bool _reservedControllerSlot = false;
  bool _visible = false;
  ScrollPosition? _scroll;

  @override
  void initState() {
    super.initState();
    _slotReleased.addListener(_onSlotReleased);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scroll = Scrollable.maybeOf(context)?.position;
    if (!identical(scroll, _scroll)) {
      _scroll?.removeListener(_checkVisibility);
      _scroll = scroll?..addListener(_checkVisibility);
    }
  }

  @override
  void didUpdateWidget(covariant _ReplayVideoThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeController();
      _ready = false;
      if (_visible) _load();
    }
  }

  /// Está (ao menos em parte) dentro da tela?
  bool _isOnScreen() {
    if (!mounted) return false;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final screen = MediaQuery.sizeOf(context);
    return rect.bottom > 0 &&
        rect.top < screen.height &&
        rect.right > 0 &&
        rect.left < screen.width;
  }

  void _checkVisibility() {
    final visible = _isOnScreen();
    if (visible == _visible) return;
    _visible = visible;
    if (visible) {
      _load();
    } else if (_controller != null) {
      _disposeController();
      if (mounted) setState(() => _ready = false);
    }
  }

  void _onSlotReleased() {
    if (_visible && _controller == null) _load();
  }

  Future<void> _load() async {
    if (_controller != null || _liveControllers >= _maxLiveControllers) return;
    _liveControllers++;
    _reservedControllerSlot = true;

    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setVolume(0);
      final duration = controller.value.duration;
      final target = duration > const Duration(milliseconds: 700)
          ? const Duration(milliseconds: 500)
          : Duration.zero;
      await controller.seekTo(target);
      await controller.pause();
      if (mounted && identical(_controller, controller)) {
        setState(() => _ready = true);
      }
    } catch (_) {
      if (identical(_controller, controller)) {
        _controller = null;
        _releaseControllerSlot();
      }
      await controller.dispose();
    }
  }

  void _releaseControllerSlot() {
    if (!_reservedControllerSlot) return;
    _reservedControllerSlot = false;
    if (_liveControllers > 0) _liveControllers--;
    _slotReleased.value++;
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    controller?.dispose();
    _releaseControllerSlot();
  }

  @override
  void dispose() {
    _scroll?.removeListener(_checkVisibility);
    _slotReleased.removeListener(_onSlotReleased);
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_ready || controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}

class _ReplayPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = AppColors.onDark.withAlpha(30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final fill = Paint()
      ..color = AppColors.primaryPressed.withAlpha(110)
      ..style = PaintingStyle.fill;

    canvas.drawRect(Offset.zero & size, fill);
    for (var i = 0; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawRect(
        Rect.fromLTWH(x, 0, size.width / 8, size.height),
        Paint()
          ..color = AppColors.onDark.withAlpha(i.isEven ? 12 : 5)
          ..style = PaintingStyle.fill,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(6, 8, size.width - 12, size.height - 16),
      line,
    );
    canvas.drawLine(
      Offset(size.width / 2, 8),
      Offset(size.width / 2, size.height - 8),
      line,
    );
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 14, line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class OldReplaysSection extends StatelessWidget {
  final List<ReplayClip> replays;
  final String groupId;
  final String? accessToken;
  final bool isDark;

  const OldReplaysSection({
    super.key,
    required this.replays,
    required this.groupId,
    required this.accessToken,
    required this.isDark,
  });

  void _openPlayer(BuildContext context, int index) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ReplayVideoPlayerPage(
        clips: replays,
        initialIndex: index,
        groupId: groupId,
        accessToken: accessToken,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: replays.length,
        itemBuilder: (ctx, i) {
          final clip = replays[i];
          final hasUrl = resolveClipUrl(clip, groupId, accessToken) != null;
          return _ReplayChip(
            clip: clip,
            index: i + 1,
            hasUrl: hasUrl,
            isDark: isDark,
            onTap: hasUrl ? () => _openPlayer(context, i) : null,
          );
        },
      ),
    );
  }
}

// ── Chip individual (card compacto para strip horizontal) ─────────────────────

class _ReplayChip extends StatelessWidget {
  final ReplayClip clip;
  final int index;
  final bool hasUrl;
  final bool isDark;
  final VoidCallback? onTap;

  const _ReplayChip({
    required this.clip,
    required this.index,
    required this.hasUrl,
    required this.isDark,
    this.onTap,
  });

  String get _eventIcon {
    final t = clip.eventType?.toLowerCase() ?? '';
    if (t.contains('gol') || t.contains('goal')) return '⚽';
    if (t.contains('defesa') || t.contains('save')) return '🧤';
    if (t.contains('falta') || t.contains('foul')) return '🟡';
    return '🎬';
  }

  String get _label {
    if (clip.scorerName?.isNotEmpty == true) return clip.scorerName!;
    if (clip.eventType?.isNotEmpty == true) return clip.eventType!;
    return 'Lance';
  }

  @override
  Widget build(BuildContext context) {
    final border = isDark ? AppColors.slate700 : AppColors.slate200;
    final bg = isDark ? AppColors.slate800 : AppColors.onDark;

    return Padding(
      padding: const EdgeInsets.only(right: 10, top: 4, bottom: 4),
      child: Material(
        color: AppColors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: 92,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Thumbnail area ─────────────────────────────────────
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(11)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(color: AppColors.lightText),

                        Center(
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  AppColors.onDark.withAlpha(hasUrl ? 28 : 14),
                              border: Border.all(
                                color: AppColors.onDark
                                    .withAlpha(hasUrl ? 55 : 25),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              hasUrl
                                  ? Icons.play_arrow_rounded
                                  : Icons.videocam_off_rounded,
                              size: 20,
                              color:
                                  AppColors.onDark.withAlpha(hasUrl ? 220 : 70),
                            ),
                          ),
                        ),

                        // Badge do índice
                        Positioned(
                          top: 5,
                          left: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.darkApp.withAlpha(150),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('#$index',
                                style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.onDark)),
                          ),
                        ),

                        // Minuto (canto inferior direito)
                        if (clip.minute != null)
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.darkApp.withAlpha(150),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text("${clip.minute}'",
                                  style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.onDark70)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Info area ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                  child: Row(
                    children: [
                      Text(_eventIcon, style: const TextStyle(fontSize: 10)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          _label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark ? AppColors.onDark : AppColors.slate900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/api/api_constants.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/replay_clip.dart';
import '../providers/replays_provider.dart';

// Presets de velocidade (câmera lenta → normal → rápido). Paridade com o site.
const List<double> _kSpeeds = [0.25, 0.5, 1.0, 1.5, 2.0];
// Passo aproximado de um quadro a 30fps.
const Duration _kFrameStep = Duration(milliseconds: 33);
const String _kSpeedPrefKey = 'replay_speed';
const String _kLoopPrefKey = 'replay_loop';
const String _kSiteUrl = String.fromEnvironment(
  'WEB_URL',
  defaultValue: 'https://bratnavafc.com',
);

// ── URL resolver (shared) ─────────────────────────────────────────────────────

/// Returns the best playable URL for [clip]:
/// 1. Direct pre-signed `videoUrl` (Cloudflare R2 — no auth needed).
/// 2. Authenticated backend stream endpoint.
String? resolveClipUrl(ReplayClip clip, String groupId, String? accessToken) {
  if (clip.videoUrl != null && clip.videoUrl!.isNotEmpty) return clip.videoUrl;
  if (clip.clipId.isNotEmpty) {
    final path = ApiConstants.replayStream(groupId, clip.clipId);
    return '${AppConstants.apiUrl}$path?t=${accessToken ?? ''}';
  }
  return null;
}

// ── Page ──────────────────────────────────────────────────────────────────────

class ReplayVideoPlayerPage extends ConsumerStatefulWidget {
  final List<ReplayClip> clips;
  final int initialIndex;
  final String groupId;
  final String? accessToken;
  final ValueChanged<ReplayClip>? onClipChanged;

  const ReplayVideoPlayerPage({
    super.key,
    required this.clips,
    required this.initialIndex,
    required this.groupId,
    this.accessToken,
    this.onClipChanged,
  });

  @override
  ConsumerState<ReplayVideoPlayerPage> createState() =>
      _ReplayVideoPlayerPageState();
}

class _ReplayVideoPlayerPageState extends ConsumerState<ReplayVideoPlayerPage> {
  late int _index;
  late List<ReplayClip> _clips;
  late VideoPlayerController _ctrl;

  bool _initialised = false;
  bool _hasError = false;
  bool _showControls = true;
  bool _isFullscreen = false;
  bool _actionBusy = false;

  double _speed = 1.0;
  bool _loop = false;

  // ── Helpers ───────────────────────────────────────────────────────────────

  ReplayClip get _clip => _clips[_index];
  bool get _hasPrev => _index > 0;
  bool get _hasNext => _index < _clips.length - 1;
  String? get _currentUrl =>
      resolveClipUrl(_clip, widget.groupId, widget.accessToken);

  String get _publicClipUrl {
    final base = _kSiteUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/#/public/clip/${_clip.clipId}';
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _clips = List<ReplayClip>.from(widget.clips);
    _loadPrefs();
    _initController();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final s = prefs.getDouble(_kSpeedPrefKey);
    final l = prefs.getBool(_kLoopPrefKey);
    setState(() {
      if (s != null && _kSpeeds.contains(s)) _speed = s;
      if (l != null) _loop = l;
    });
    if (_initialised) {
      _ctrl.setPlaybackSpeed(_speed);
      _ctrl.setLooping(_loop);
    }
  }

  void _initController() {
    final url = _currentUrl;
    if (url == null) {
      setState(() {
        _hasError = true;
        _initialised = false;
      });
      return;
    }
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialised = true);
        _ctrl
          ..setPlaybackSpeed(_speed)
          ..setLooping(_loop)
          ..play()
          // Listener enxuto: só cuida do auto-avanço; a UI que depende do
          // tempo é reconstruída via ValueListenableBuilder (sem rebuild global).
          ..addListener(_onEnd);
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _hasError = true);
      });
  }

  void _onEnd() {
    if (!mounted || _loop) return;
    final v = _ctrl.value;
    if (v.isInitialized &&
        !v.isPlaying &&
        !v.isBuffering &&
        v.duration > Duration.zero &&
        v.position >= v.duration - const Duration(milliseconds: 300) &&
        _hasNext) {
      _goTo(_index + 1);
    }
  }

  void _goTo(int index) {
    _ctrl
      ..removeListener(_onEnd)
      ..pause()
      ..dispose();
    setState(() {
      _index = index;
      _initialised = false;
      _hasError = false;
    });
    _initController();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _ctrl
      ..removeListener(_onEnd)
      ..dispose();
    super.dispose();
  }

  // ── Velocidade / loop / quadro a quadro ─────────────────────────────────────

  Future<void> _applySpeed(double s) async {
    setState(() => _speed = s);
    if (_initialised) _ctrl.setPlaybackSpeed(s);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kSpeedPrefKey, s);
  }

  Future<void> _toggleLoop() async {
    final next = !_loop;
    setState(() => _loop = next);
    if (_initialised) _ctrl.setLooping(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLoopPrefKey, next);
  }

  void _frameStep(int dir) {
    if (!_initialised) return;
    _ctrl.pause();
    final pos = _ctrl.value.position + (_kFrameStep * dir);
    final dur = _ctrl.value.duration;
    _ctrl.seekTo(pos < Duration.zero ? Duration.zero : (pos > dur ? dur : pos));
  }

  // ── Playback controls ─────────────────────────────────────────────────────

  void _toggleFullscreen() {
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    setState(() => _isFullscreen = !_isFullscreen);
  }

  void _seek(Duration delta) {
    final pos = _ctrl.value.position;
    final dur = _ctrl.value.duration;
    final raw = pos + delta;
    final next = raw < Duration.zero ? Duration.zero : (raw > dur ? dur : raw);
    _ctrl.seekTo(next);
  }

  // ── Social actions ────────────────────────────────────────────────────────

  Future<void> _toggleLike() async {
    if (_actionBusy || _clip.clipId.isEmpty) return;
    final ds = ref.read(replaysDsProvider);
    final prev = _clip;
    setState(() {
      _actionBusy = true;
      _clips[_index] = _clip.copyWith(
        isLiked: !_clip.isLiked,
        likeCount: _clip.isLiked ? _clip.likeCount - 1 : _clip.likeCount + 1,
      );
      widget.onClipChanged?.call(_clips[_index]);
    });
    try {
      final result = await ds.toggleLike(widget.groupId, _clip.clipId);
      if (mounted) {
        setState(() {
          _clips[_index] = _clips[_index].copyWith(
            isLiked: result.isLiked,
            likeCount: result.likeCount,
          );
          widget.onClipChanged?.call(_clips[_index]);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _clips[_index] = prev;
          widget.onClipChanged?.call(_clips[_index]);
        });
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_actionBusy || _clip.clipId.isEmpty) return;
    final ds = ref.read(replaysDsProvider);
    final prev = _clip;
    setState(() {
      _actionBusy = true;
      _clips[_index] = _clip.copyWith(isFavorited: !_clip.isFavorited);
      widget.onClipChanged?.call(_clips[_index]);
    });
    try {
      final isFav = await ds.toggleFavorite(widget.groupId, _clip.clipId);
      if (mounted) {
        setState(() {
          _clips[_index] = _clips[_index].copyWith(isFavorited: isFav);
          widget.onClipChanged?.call(_clips[_index]);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _clips[_index] = prev;
          widget.onClipChanged?.call(_clips[_index]);
        });
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  void _openLikersSheet() {
    if (_clip.clipId.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _LikersSheet(
        future: ref
            .read(replaysDsProvider)
            .fetchLikers(widget.groupId, _clip.clipId),
        likeCount: _clip.likeCount,
      ),
    );
  }

  void _copyUrl() {
    Clipboard.setData(ClipboardData(text: _publicClipUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link do site copiado!')),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06101F),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF06101F),
              Color(0xFF0F172A),
              Color(0xFF08111F),
            ],
          ),
        ),
        child: Column(children: [
          if (!_isFullscreen)
            SafeArea(
              bottom: false,
              child: _TopBar(
                clip: _clip,
                index: _index,
                total: _clips.length,
                onBack: () => Navigator.pop(context),
              ),
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                _isFullscreen ? 0 : 14,
                _isFullscreen ? 0 : 10,
                _isFullscreen ? 0 : 14,
                _isFullscreen ? 0 : 8,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_isFullscreen ? 0 : 24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(
                      color: _isFullscreen
                          ? Colors.transparent
                          : Colors.white.withAlpha(28),
                    ),
                    boxShadow: _isFullscreen
                        ? const []
                        : const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 24,
                              offset: Offset(0, 14),
                            ),
                          ],
                  ),
                  child: GestureDetector(
                    onTap: () => setState(() => _showControls = !_showControls),
                    child: Stack(alignment: Alignment.center, children: [
                      Container(color: Colors.black),

                      if (_initialised)
                        AspectRatio(
                          aspectRatio: _ctrl.value.aspectRatio,
                          child: VideoPlayer(_ctrl),
                        ),

                      if (!_initialised && !_hasError)
                        const CircularProgressIndicator(color: Colors.white),

                      if (_hasError)
                        _ErrorOverlay(
                          onRetry: () {
                            setState(() {
                              _hasError = false;
                              _initialised = false;
                            });
                            _initController();
                          },
                        ),

                      // Controles: só a subárvore que depende do tempo é reconstruída,
                      // via ValueListenableBuilder (sem rebuild global por tick).
                      if (_initialised && _showControls)
                        ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: _ctrl,
                          builder: (_, v, __) => _ControlsOverlay(
                            isPlaying: v.isPlaying,
                            isBuffering: v.isBuffering,
                            isFullscreen: _isFullscreen,
                            hasPrev: _hasPrev,
                            hasNext: _hasNext,
                            speed: _speed,
                            loop: _loop,
                            onPlayPause: () =>
                                v.isPlaying ? _ctrl.pause() : _ctrl.play(),
                            onSeekBack: () =>
                                _seek(const Duration(seconds: -10)),
                            onSeekForward: () =>
                                _seek(const Duration(seconds: 10)),
                            onPrev: _hasPrev ? () => _goTo(_index - 1) : null,
                            onNext: _hasNext ? () => _goTo(_index + 1) : null,
                            onFramePrev: () => _frameStep(-1),
                            onFrameNext: () => _frameStep(1),
                            onSpeed: _applySpeed,
                            onLoop: _toggleLoop,
                            onFullscreen: _toggleFullscreen,
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          if (_initialised) _ProgressBar(ctrl: _ctrl, fmt: _fmt),
          if (!_isFullscreen)
            SafeArea(
              top: false,
              child: _SocialDock(
                clip: _clip,
                onLike: _clip.clipId.isNotEmpty ? _toggleLike : null,
                onFavorite: _clip.clipId.isNotEmpty ? _toggleFavorite : null,
                onCopy: _copyUrl,
                onShowLikers: _clip.likeCount > 0 ? _openLikersSheet : null,
                busy: _actionBusy,
              ),
            ),
        ]),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final ReplayClip clip;
  final int index;
  final int total;
  final VoidCallback onBack;

  const _TopBar({
    required this.clip,
    required this.index,
    required this.total,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final label = clip.scorerName?.isNotEmpty == true
        ? clip.scorerName!
        : (clip.eventType ?? 'Replay');
    final type = (clip.eventType ?? 'Replay').toUpperCase();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(6, 8, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(25)),
      ),
      child: Row(children: [
        CircleIconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: type == 'GOL'
                        ? const Color(0xFF10B981)
                        : const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(type,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
              const SizedBox(height: 2),
              Text(
                [
                  '${index + 1} de $total',
                  if (clip.minute != null) "${clip.minute}'",
                  if (clip.teamName?.isNotEmpty == true) clip.teamName!,
                  if (clip.matchPlace.isNotEmpty) clip.matchPlace,
                ].join('  |  '),
                style: const TextStyle(color: Colors.white60, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class TopBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? label;
  final VoidCallback? onTap;
  final String? tooltip;

  const TopBtn({
    super.key,
    required this.icon,
    required this.color,
    this.label,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: color),
            if (label != null) ...[
              const SizedBox(width: 3),
              Text(label!, style: TextStyle(fontSize: 12, color: color)),
            ],
          ]),
        ),
      ),
    );
  }
}

// ── Controls overlay ──────────────────────────────────────────────────────────

class _SocialDock extends StatelessWidget {
  final ReplayClip clip;
  final VoidCallback? onLike;
  final VoidCallback? onFavorite;
  final VoidCallback onCopy;
  final VoidCallback? onShowLikers;
  final bool busy;

  const _SocialDock({
    required this.clip,
    this.onLike,
    this.onFavorite,
    required this.onCopy,
    this.onShowLikers,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(24),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withAlpha(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
              child: _SocialPill(
                icon: clip.isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: clip.isLiked ? 'Curtido' : 'Curtir',
                value: clip.likeCount > 0 ? '${clip.likeCount}' : null,
                active: clip.isLiked,
                activeColor: const Color(0xFFFF4D6D),
                onTap: busy ? null : onLike,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SocialPill(
                icon: clip.isFavorited
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                label: clip.isFavorited ? 'Salvo' : 'Salvar',
                active: clip.isFavorited,
                activeColor: const Color(0xFFF59E0B),
                onTap: busy ? null : onFavorite,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SocialPill(
                icon: Icons.ios_share_rounded,
                label: 'Link',
                active: false,
                activeColor: const Color(0xFF38BDF8),
                onTap: onCopy,
              ),
            ),
          ]),
          if (clip.likeCount > 0) ...[
            const SizedBox(height: 8),
            Material(
              color: Colors.white.withAlpha(16),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: onShowLikers,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      _LikerStack(count: clip.likeCount),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          clip.likeCount == 1
                              ? '1 pessoa curtiu este replay'
                              : '${clip.likeCount} pessoas curtiram este replay',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_up_rounded,
                          color: Colors.white70, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _SocialPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final bool active;
  final Color activeColor;
  final VoidCallback? onTap;

  const _SocialPill({
    required this.icon,
    required this.label,
    this.value,
    required this.active,
    required this.activeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : Colors.white70;
    return Material(
      color: active ? activeColor.withAlpha(32) : Colors.white.withAlpha(18),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withAlpha(35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      value!,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

class _LikerStack extends StatelessWidget {
  final int count;

  const _LikerStack({required this.count});

  @override
  Widget build(BuildContext context) {
    final visible = count.clamp(1, 3).toInt();
    return SizedBox(
      width: 22.0 + ((visible - 1) * 16),
      height: 28,
      child: Stack(
        children: [
          for (var i = 0; i < visible; i++)
            Positioned(
              left: i * 16,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: [
                    const Color(0xFFFF4D6D),
                    const Color(0xFF8B5CF6),
                    const Color(0xFF38BDF8),
                  ][i],
                  border: Border.all(color: const Color(0xFF06101F), width: 2),
                ),
                child: const Icon(Icons.favorite_rounded,
                    size: 13, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _LikersSheet extends StatelessWidget {
  final Future<List<ReplayLiker>> future;
  final int likeCount;

  const _LikersSheet({
    required this.future,
    required this.likeCount,
  });

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    String firstLetter(String value) => value.substring(0, 1).toUpperCase();
    if (parts.length == 1) return firstLetter(parts.first);
    return '${firstLetter(parts.first)}${firstLetter(parts.last)}';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: .48,
      minChildSize: .28,
      maxChildSize: .82,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF4D6D),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_rounded,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Curtido por',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            likeCount == 1
                                ? '1 curtida neste replay'
                                : '$likeCount curtidas neste replay',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<ReplayLiker>>(
                  future: future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Nao foi possivel carregar as curtidas.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    final likers = snapshot.data ?? const <ReplayLiker>[];
                    if (likers.isEmpty) {
                      return const Center(
                        child: Text(
                          'Ainda nao ha curtidas neste replay.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: likers.length,
                      separatorBuilder: (_, __) => Divider(
                        color: Colors.white.withAlpha(18),
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final liker = likers[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: const Color(0xFF1D4ED8),
                            child: Text(
                              _initials(liker.userName),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          title: Text(
                            liker.userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          trailing: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4D6D).withAlpha(28),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.favorite_rounded,
                                color: Color(0xFFFF4D6D), size: 18),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CircleIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;

  const CircleIconButton({super.key, required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withAlpha(20),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        icon: icon,
        splashRadius: 22,
      ),
    );
  }
}

class _ControlsOverlay extends StatelessWidget {
  final bool isPlaying;
  final bool isBuffering;
  final bool isFullscreen;
  final bool hasPrev;
  final bool hasNext;
  final double speed;
  final bool loop;
  final VoidCallback onPlayPause;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onFramePrev;
  final VoidCallback onFrameNext;
  final ValueChanged<double> onSpeed;
  final VoidCallback onLoop;
  final VoidCallback onFullscreen;

  const _ControlsOverlay({
    required this.isPlaying,
    required this.isBuffering,
    required this.isFullscreen,
    required this.hasPrev,
    required this.hasNext,
    required this.speed,
    required this.loop,
    required this.onPlayPause,
    required this.onSeekBack,
    required this.onSeekForward,
    this.onPrev,
    this.onNext,
    required this.onFramePrev,
    required this.onFrameNext,
    required this.onSpeed,
    required this.onLoop,
    required this.onFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xAA000000),
            Color(0x00000000),
            Color(0x00000000),
            Color(0xAA000000),
          ],
          stops: [0.0, 0.25, 0.75, 1.0],
        ),
      ),
      child: Stack(children: [
        // Transporte central (com quadro a quadro nas pontas internas)
        Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _CtrlBtn(
                icon: Icons.skip_previous_rounded,
                size: 26,
                onTap: onPrev,
                disabled: !hasPrev),
            _CtrlBtn(
                icon: Icons.navigate_before_rounded,
                size: 26,
                onTap: onFramePrev),
            const SizedBox(width: 4),
            _CtrlBtn(
                icon: Icons.replay_10_rounded, size: 30, onTap: onSeekBack),
            const SizedBox(width: 12),
            isBuffering
                ? const SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3))
                : _CtrlBtn(
                    icon: isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 50,
                    onTap: onPlayPause),
            const SizedBox(width: 12),
            _CtrlBtn(
                icon: Icons.forward_10_rounded, size: 30, onTap: onSeekForward),
            const SizedBox(width: 4),
            _CtrlBtn(
                icon: Icons.navigate_next_rounded,
                size: 26,
                onTap: onFrameNext),
            _CtrlBtn(
                icon: Icons.skip_next_rounded,
                size: 26,
                onTap: onNext,
                disabled: !hasNext),
          ]),
        ),
        // Barra inferior: velocidade / câmera lenta + loop
        Positioned(
          left: 12,
          right: 12,
          bottom: 10,
          child: Row(children: [
            Expanded(child: _SpeedBar(speed: speed, onSpeed: onSpeed)),
            const SizedBox(width: 8),
            _CtrlBtn(
              icon: Icons.loop_rounded,
              size: 20,
              onTap: onLoop,
              highlighted: loop,
            ),
            const SizedBox(width: 6),
            _CtrlBtn(
              icon: isFullscreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              size: 22,
              onTap: onFullscreen,
            ),
          ]),
        ),
        if (isFullscreen)
          Positioned(
            top: 16,
            left: 16,
            child: _CtrlBtn(
              icon: Icons.arrow_back_rounded,
              size: 22,
              onTap: () => Navigator.pop(context),
            ),
          ),
      ]),
    );
  }
}

// ── Barra de velocidade (segmentada) ────────────────────────────────────────────

class _SpeedBar extends StatelessWidget {
  final double speed;
  final ValueChanged<double> onSpeed;
  const _SpeedBar({required this.speed, required this.onSpeed});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: const Color(0x55000000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final s in _kSpeeds)
          GestureDetector(
            onTap: () => onSpeed(s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: speed == s ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${s == s.roundToDouble() ? s.toInt() : s}×',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: speed == s ? const Color(0xFF0F172A) : Colors.white70,
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final bool disabled;
  final bool highlighted;

  const _CtrlBtn({
    required this.icon,
    this.size = 28,
    this.onTap,
    this.disabled = false,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.3 : 1.0,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          width: size + 18,
          height: size + 18,
          decoration: BoxDecoration(
            color:
                highlighted ? const Color(0xAA34D399) : const Color(0x55000000),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );
  }
}

// ── Progress bar ──────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final VideoPlayerController ctrl;
  final String Function(Duration) fmt;
  const _ProgressBar({required this.ctrl, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(children: [
        // Só o texto de posição precisa atualizar por tick.
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: ctrl,
          builder: (_, v, __) => Text(fmt(v.position),
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontFamily: 'monospace')),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: VideoProgressIndicator(
              ctrl,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Color(0xFF34D399),
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white12,
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        Text(fmt(ctrl.value.duration),
            style: const TextStyle(
                color: Colors.white54, fontSize: 11, fontFamily: 'monospace')),
      ]),
    );
  }
}

// ── Error overlay ─────────────────────────────────────────────────────────────

class _ErrorOverlay extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorOverlay({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: Colors.white54, size: 48),
      const SizedBox(height: 12),
      const Text('Não foi possível carregar o vídeo.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
          textAlign: TextAlign.center),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh, color: Colors.white70),
        label: const Text('Tentar novamente',
            style: TextStyle(color: Colors.white70)),
      ),
    ]);
  }
}

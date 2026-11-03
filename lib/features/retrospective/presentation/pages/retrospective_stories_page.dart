import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/share/image_share.dart';
import '../../../../core/theme/retro_colors.dart';
import '../../domain/entities/player_retrospective.dart';
import '../../domain/retrospective_stories.dart';
import '../widgets/retro_story_card.dart';

/// Stories da retrospectiva em tela cheia, como no Instagram: toque à direita
/// avança, à esquerda volta, segurar pausa e cada story passa sozinho em 6 s.
class RetrospectiveStoriesPage extends StatefulWidget {
  final PlayerRetrospective r;
  const RetrospectiveStoriesPage({super.key, required this.r});

  static const storyDuration = Duration(seconds: 6);

  @override
  State<RetrospectiveStoriesPage> createState() =>
      _RetrospectiveStoriesPageState();
}

class _RetrospectiveStoriesPageState extends State<RetrospectiveStoriesPage>
    with SingleTickerProviderStateMixin {
  late final List<StoryMeta> _stories = storiesFor(widget.r);
  late final AnimationController _timer = AnimationController(
      vsync: this, duration: RetrospectiveStoriesPage.storyDuration)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && _index < _stories.length - 1) {
        _go(1);
      }
    });
  int _index = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (_stories.isNotEmpty) _timer.forward();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _timer.dispose();
    super.dispose();
  }

  void _go(int step) {
    final next = (_index + step).clamp(0, _stories.length - 1);
    setState(() => _index = next);
    _timer.forward(from: 0);
  }

  void _pause() => _timer.stop();
  void _resume() {
    if (!_timer.isCompleted) _timer.forward();
  }

  Future<void> _share() async {
    _pause();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RetroColors.darkB,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => RetroShareSheet(r: widget.r, story: _stories[_index]),
    );
    if (mounted) _resume();
  }

  @override
  Widget build(BuildContext context) {
    if (_stories.isEmpty) {
      return Scaffold(
        backgroundColor: RetroColors.ink,
        appBar: AppBar(
            backgroundColor: RetroColors.ink,
            foregroundColor: RetroColors.white),
        body: const Center(
            child: Text('Sem jogos no período.',
                style: TextStyle(color: RetroColors.white))),
      );
    }
    final story = _stories[_index];
    return Scaffold(
      backgroundColor: RetroColors.ink,
      body: SafeArea(
        child: Center(
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: LayoutBuilder(builder: (context, c) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) =>
                    _go(d.localPosition.dx < c.maxWidth * .4 ? -1 : 1),
                onLongPressStart: (_) => _pause(),
                onLongPressEnd: (_) => _resume(),
                child: Stack(children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: RetroStoryCard(
                          key: ValueKey(story.id), r: widget.r, story: story),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: AnimatedBuilder(
                      animation: _timer,
                      builder: (_, __) => Row(children: [
                        for (var i = 0; i < _stories.length; i++) ...[
                          if (i > 0) const SizedBox(width: 4),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                minHeight: 3,
                                value: i < _index
                                    ? 1
                                    : (i == _index ? _timer.value : 0),
                                backgroundColor: RetroColors.white30,
                                valueColor: const AlwaysStoppedAnimation(
                                    RetroColors.white),
                              ),
                            ),
                          ),
                        ],
                      ]),
                    ),
                  ),
                  Positioned(
                    top: 18,
                    right: 4,
                    child: IconButton(
                      tooltip: 'Fechar',
                      color: story.theme == StoryTheme.yellow
                          ? RetroColors.ink
                          : RetroColors.white,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: RetroColors.white,
                        foregroundColor: RetroColors.ink,
                        shape: const StadiumBorder(),
                        elevation: 4,
                      ),
                      onPressed: _share,
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('Compartilhar'),
                    ),
                  ),
                ]),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Folha de compartilhar: prévia e a imagem 1080×1920 (180 × 6) com a marca PatotasApp.
class RetroShareSheet extends StatefulWidget {
  final PlayerRetrospective r;
  final StoryMeta story;
  const RetroShareSheet({super.key, required this.r, required this.story});

  static const previewWidth = 180.0;
  static const pixelRatio = 6.0; // 180 × 6 = 1080, 320 × 6 = 1920

  @override
  State<RetroShareSheet> createState() => _RetroShareSheetState();
}

class _RetroShareSheetState extends State<RetroShareSheet> {
  final _boundary = GlobalKey();
  bool _busy = false;

  Future<void> _run(Future<String?> Function(Uint8List png) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final png = await ImageShare.capture(_boundary,
          pixelRatio: RetroShareSheet.pixelRatio);
      final msg = await action(png);
      if (msg != null) messenger.showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Não foi possível gerar a imagem.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _name => storyFileName(widget.r, widget.story);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: RetroColors.white30,
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 14),
              Text('Compartilhar “${widget.story.name}”',
                  style: text.titleMedium?.copyWith(
                      color: RetroColors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('Imagem 1080×1920 com a marca PatotasApp',
                  style: text.bodySmall?.copyWith(
                      color: RetroColors.white.withValues(alpha: .6))),
              const SizedBox(height: 14),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RepaintBoundary(
                    key: _boundary,
                    child: SizedBox(
                      width: RetroShareSheet.previewWidth,
                      child: RetroStoryCard(
                          r: widget.r, story: widget.story, still: true),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                _Option(
                  label: 'Story do Instagram',
                  icon: Icons.camera_alt_outlined,
                  gradient: RetroColors.instagram,
                  busy: _busy,
                  onTap: () => _run((png) async {
                    final ok = await ImageShare.shareToInstagramStory(png,
                        name: _name);
                    if (ok) return null;
                    await ImageShare.shareSystem(png, name: _name);
                    return 'Instagram não encontrado: abrimos as outras opções.';
                  }),
                ),
                const SizedBox(width: 10),
                _Option(
                  label: 'Copiar imagem',
                  icon: Icons.copy_rounded,
                  gradient: const [RetroColors.greenB, RetroColors.greenB],
                  busy: _busy,
                  onTap: () => _run((png) async => await ImageShare.copyImage(
                          png,
                          name: _name)
                      ? 'Imagem copiada. É só colar no WhatsApp ou onde quiser.'
                      : 'Não deu para copiar. Use Mais opções.'),
                ),
                const SizedBox(width: 10),
                _Option(
                  label: 'Mais opções',
                  icon: Icons.more_horiz_rounded,
                  gradient: const [RetroColors.darkA, RetroColors.darkA],
                  busy: _busy,
                  onTap: () => _run((png) async {
                    await ImageShare.shareSystem(png,
                        name: _name,
                        text:
                            'Minha retrospectiva ${widget.r.period.label} no PatotasApp');
                    return null;
                  }),
                ),
              ]),
            ]),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final bool busy;
  final VoidCallback onTap;

  const _Option(
      {required this.label,
      required this.icon,
      required this.gradient,
      required this.busy,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: RetroColors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Column(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight),
                ),
                child: Icon(icon, size: 18, color: RetroColors.white),
              ),
              const SizedBox(height: 7),
              Text(label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: RetroColors.white, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/share/image_share.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/team_builder_models.dart';
import '../../domain/team_builder_format.dart';
import 'team_builder_share_card.dart';

Color _muted(BuildContext context) =>
    context.isDarkTheme ? AppColors.darkTextMuted : AppColors.lightTextMuted;

Widget _grab(BuildContext context) => Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 12),
        decoration: BoxDecoration(
            color: context.appBorder, borderRadius: BorderRadius.circular(4)),
      ),
    );

// ── Escolher jogadores ───────────────────────────────────────────────────────

Future<void> showTeamBuilderPicker(
  BuildContext context, {
  required List<TeamBuilderPlayer> players,
  required List<TeamBuilderPlayer> Function() selected,
  required void Function(TeamBuilderPlayer) onToggle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.appSurface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) =>
        _PickerSheet(players: players, selected: selected, onToggle: onToggle),
  );
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet(
      {required this.players, required this.selected, required this.onToggle});

  final List<TeamBuilderPlayer> players;
  final List<TeamBuilderPlayer> Function() selected;
  final void Function(TeamBuilderPlayer) onToggle;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected();
    final q = _query.trim().toLowerCase();
    final shown = widget.players
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .toList();
    final muted = _muted(context);

    return FractionallySizedBox(
      heightFactor: .82,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _grab(context),
            Row(children: [
              Text('Escolher jogadores',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary)),
              const SizedBox(width: 8),
              Text('${selected.length}/$teamBuilderMaxPlayers',
                  style: TextStyle(fontSize: 12, color: muted)),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Pronto',
                    style: TextStyle(
                        color: AppColors.accent, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Buscar jogador',
                isDense: true,
                filled: true,
                fillColor: context.appSurfaceSubtle,
                prefixIcon: Icon(Icons.search_rounded, color: muted, size: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.appBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.appBorder)),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: shown.length,
                itemBuilder: (_, i) {
                  final p = shown[i];
                  final on = selected.any((s) => s.id == p.id);
                  final disabled = !on && !canAddPlayer(selected, p);
                  return Opacity(
                    opacity: disabled ? .35 : 1,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: disabled
                          ? null
                          : () {
                              widget.onToggle(p);
                              setState(() {});
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 9),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: p.isGoalkeeper
                                ? AppColors.goalkeeperYellow
                                : context.appSurfaceElevated,
                            child: Text(initialsOf(p.name),
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: p.isGoalkeeper
                                        ? AppColors.slate950
                                        : context.appTextPrimary)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name,
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: context.appTextPrimary)),
                                Text(
                                    '${p.isGoalkeeper ? 'Goleiro · ' : ''}${p.games} ${p.games == 1 ? 'jogo' : 'jogos'} no período',
                                    style: TextStyle(
                                        fontSize: 11.5, color: muted)),
                              ],
                            ),
                          ),
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  on ? AppColors.accent : AppColors.transparent,
                              border: Border.all(
                                  color:
                                      on ? AppColors.accent : context.appBorder,
                                  width: 2),
                            ),
                            child: on
                                ? const Icon(Icons.check_rounded,
                                    size: 14, color: AppColors.onAccent)
                                : null,
                          ),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Compartilhar ─────────────────────────────────────────────────────────────

Future<void> showTeamBuilderShare(
  BuildContext context, {
  required TeamBuilderStats stats,
  required List<TeamBuilderPlayer> players,
  required String groupName,
  required String period,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.appSurface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _ShareSheet(
        stats: stats, players: players, groupName: groupName, period: period),
  );
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet(
      {required this.stats,
      required this.players,
      required this.groupName,
      required this.period});

  final TeamBuilderStats stats;
  final List<TeamBuilderPlayer> players;
  final String groupName;
  final String period;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _cardKey = GlobalKey();
  Future<void>? _logo;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _logo ??= precacheImage(const AssetImage(teamBuilderShareLogo), context);
  }

  Future<void> _run(Future<String?> Function(Uint8List png) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _logo;
      // Garante que o quadro com o logo já foi pintado antes de capturar.
      await WidgetsBinding.instance.endOfFrame;
      final png = await ImageShare.capture(_cardKey,
          pixelRatio: 1080 / teamBuilderShareCardWidth);
      final msg = await action(png);
      if (msg != null) messenger.showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Não deu para gerar a imagem. Tente de novo.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _story() => _run((png) async {
        if (await ImageShare.shareToInstagramStory(png, name: 'monte-seu-time'))
          return null;
        await ImageShare.shareSystem(png, name: 'monte-seu-time');
        return 'Instagram não encontrado. Abrimos o menu de compartilhar.';
      });

  void _copy() => _run((png) async =>
      await ImageShare.copyImage(png, name: 'monte-seu-time')
          ? 'Imagem copiada. É só colar no WhatsApp ou onde quiser.'
          : 'Não deu para copiar a imagem neste aparelho.');

  void _more() => _run((png) async {
        await ImageShare.shareSystem(png, name: 'monte-seu-time');
        return null;
      });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _grab(context),
          Text('Compartilhar time',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.appTextPrimary)),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: width * .46,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FittedBox(
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: TeamBuilderShareCard(
                      stats: widget.stats,
                      players: widget.players,
                      groupName: widget.groupName,
                      period: widget.period,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            _Option(
              label: 'Story do Instagram',
              icon: Icons.camera_alt_outlined,
              gradient: const [
                AppColors.instagramOrange,
                AppColors.instagramPink,
                AppColors.instagramPurple
              ],
              onTap: _busy ? null : _story,
            ),
            const SizedBox(width: 10),
            _Option(
                label: 'Copiar imagem',
                icon: Icons.copy_rounded,
                gradient: const [AppColors.accent, AppColors.accent],
                onTap: _busy ? null : _copy),
            const SizedBox(width: 10),
            _Option(
                label: 'Mais opções',
                icon: Icons.more_horiz_rounded,
                onTap: _busy ? null : _more),
          ]),
          if (_busy) ...[
            const SizedBox(height: 12),
            const Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          ],
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option(
      {required this.label, required this.icon, this.gradient, this.onTap});

  final String label;
  final IconData icon;
  final List<Color>? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Column(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: gradient == null
                      ? null
                      : LinearGradient(
                          colors: gradient!,
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight),
                  color: gradient == null ? context.appSurfaceSubtle : null,
                  border: gradient == null
                      ? Border.all(color: context.appBorder)
                      : null,
                ),
                child: Icon(icon,
                    size: 18,
                    color: gradient == null
                        ? context.appTextPrimary
                        : AppColors.onDark),
              ),
              const SizedBox(height: 7),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary)),
            ]),
          ),
        ),
      ),
    );
  }
}

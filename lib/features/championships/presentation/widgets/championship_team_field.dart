import 'package:flutter/material.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';

/// Jogador no campo.
class FieldPlayerInfo {
  const FieldPlayerInfo({
    required this.id,
    required this.name,
    required this.isGoalkeeper,
    this.dimmed = false,
  });

  final String id;
  final String name;
  final bool isGoalkeeper;

  /// Ex.: não apareceu (didNotPlay).
  final bool dimmed;
}

/// Posições da linha por quantidade de jogadores, as mesmas do `MiniTeamField`
/// do site (MatchField.tsx). Goleiro sempre embaixo, no gol.
const _outfield = <int, List<Offset>>{
  0: [],
  1: [Offset(.50, .44)],
  2: [Offset(.28, .44), Offset(.72, .44)],
  3: [Offset(.50, .30), Offset(.22, .54), Offset(.78, .54)],
  4: [Offset(.28, .30), Offset(.72, .30), Offset(.22, .55), Offset(.78, .55)],
  5: [
    Offset(.50, .22),
    Offset(.20, .36),
    Offset(.80, .36),
    Offset(.22, .56),
    Offset(.78, .56),
  ],
  6: [
    Offset(.18, .22),
    Offset(.50, .20),
    Offset(.82, .22),
    Offset(.18, .44),
    Offset(.50, .46),
    Offset(.82, .44),
  ],
  7: [
    Offset(.14, .20),
    Offset(.38, .17),
    Offset(.62, .17),
    Offset(.86, .20),
    Offset(.16, .42),
    Offset(.50, .44),
    Offset(.84, .42),
  ],
};

const _goalkeeperSpot = Offset(.50, .86);

/// Posição de cada jogador (na ordem da lista), em fração do campo.
List<Offset> fieldPositions(List<FieldPlayerInfo> players) {
  final keeper = players.indexWhere((p) => p.isGoalkeeper);
  final outfield = [
    for (var i = 0; i < players.length; i++)
      if (i != keeper) i,
  ];
  final table = _outfield[outfield.length.clamp(0, 7)]!;
  final result = List<Offset>.filled(players.length, const Offset(.5, .5));
  if (keeper >= 0) result[keeper] = _goalkeeperSpot;
  for (var i = 0; i < outfield.length; i++) {
    // Mais de 7 na linha: os extras repetem a última posição da tabela, como
    // no site.
    result[outfield[i]] = table[i.clamp(0, table.length - 1)];
  }
  return result;
}

String fieldInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) {
    final word = parts.first;
    return word.substring(0, word.length < 2 ? word.length : 2).toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

String fieldFirstName(String name) => name.trim().split(RegExp(r'\s+')).first;

/// Campo de um time, como o do site: gramado com as linhas, cor e nome do time
/// no topo, jogadores em círculos com as iniciais e o primeiro nome sempre
/// visível embaixo; goleiro no gol com o ícone de goleiro da patota.
class ChampionshipTeamField extends StatelessWidget {
  const ChampionshipTeamField({
    super.key,
    required this.teamName,
    required this.teamColorHex,
    required this.players,
    required this.icons,
    this.maxWidth = 260,
    this.showHeader = true,
    this.selectedPlayerId,
    this.swapTargets = const {},
    this.faded = const {},
    this.onTapPlayer,
  });

  final String teamName;
  final String? teamColorHex;
  final List<FieldPlayerInfo> players;
  final GroupIcons icons;
  final double maxWidth;

  /// Cor e nome do time no topo (quem já mostra o cabeçalho pode esconder).
  final bool showHeader;

  /// Troca no próprio campo: o selecionado fica destacado, os alvos ganham o
  /// ⇄ e os do mesmo time ficam esmaecidos.
  final String? selectedPlayerId;
  final Set<String> swapTargets;
  final Set<String> faded;
  final ValueChanged<String>? onTapPlayer;

  static Color colorOf(String? hex) {
    final value = hex == null
        ? null
        : int.tryParse('FF${hex.replaceFirst('#', '')}', radix: 16);
    return value == null ? const Color(0xFF2563EB) : Color(value);
  }

  @override
  Widget build(BuildContext context) {
    final color = colorOf(teamColorHex);
    final positions = fieldPositions(players);
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHeader) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      teamName,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('${players.length}j', style: textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Semantics(
              label: 'Campo do $teamName',
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LayoutBuilder(
                    builder: (context, box) => Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(painter: _PitchPainter()),
                        ),
                        for (var i = 0; i < players.length; i++)
                          _Pin(
                            key: ValueKey('field-pin-${players[i].id}'),
                            player: players[i],
                            center: Offset(
                              positions[i].dx * box.maxWidth,
                              positions[i].dy * box.maxHeight,
                            ),
                            color: color,
                            icons: icons,
                            pinSize: (box.maxWidth * .15).clamp(24.0, 34.0),
                            selected: players[i].id == selectedPlayerId,
                            swapTarget: swapTargets.contains(players[i].id),
                            faded: faded.contains(players[i].id),
                            onTap: onTapPlayer == null
                                ? null
                                : () => onTapPlayer!(players[i].id),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({
    super.key,
    required this.player,
    required this.center,
    required this.color,
    required this.icons,
    required this.pinSize,
    this.selected = false,
    this.swapTarget = false,
    this.faded = false,
    this.onTap,
  });

  final FieldPlayerInfo player;
  final Offset center;
  final Color color;
  final GroupIcons icons;
  final double pinSize;
  final bool selected;
  final bool swapTarget;
  final bool faded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final light = color.computeLuminance() > .5;
    const labelWidth = 58.0;
    return Positioned(
      left: center.dx - labelWidth / 2,
      top: center.dy - pinSize / 2,
      width: labelWidth,
      child: Opacity(
        opacity: player.dimmed || faded ? .35 : 1,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: pinSize,
                    height: pinSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFF59E0B)
                            : light
                                ? Colors.black.withValues(alpha: .25)
                                : Colors.white.withValues(alpha: .9),
                        width: selected ? 3 : 2,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                    child: player.isGoalkeeper
                        ? renderGroupIcon(icons.goalkeeper, size: pinSize * .55)
                        : Text(
                            fieldInitials(player.name),
                            style: TextStyle(
                              color: light
                                  ? const Color(0xFF0F172A)
                                  : Colors.white,
                              fontSize: pinSize * .32,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                  if (swapTarget)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        key: ValueKey('swap-target-${player.id}'),
                        padding: const EdgeInsets.all(1),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.swap_horiz_rounded,
                            size: 13, color: Color(0xFF2563EB)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              // Nome sempre visível: só as iniciais não dizem quem é.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  fieldFirstName(player.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gramado e linhas do `FieldBg` do site (viewBox 200×300).
class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF166534), Color(0xFF15803D), Color(0xFF166534)],
        ).createShader(rect),
    );
    // Faixas do gramado.
    final stripe = Paint()..color = Colors.black.withValues(alpha: .05);
    final band = size.height / 8;
    for (var i = 1; i < 8; i += 2) {
      canvas.drawRect(Rect.fromLTWH(0, i * band, size.width, band), stripe);
    }

    final sx = size.width / 200, sy = size.height / 300;
    Rect r(double x, double y, double w, double h) =>
        Rect.fromLTWH(x * sx, y * sy, w * sx, h * sy);
    Paint line(double alpha, [double width = 1]) => Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;

    canvas.drawRRect(
      RRect.fromRectAndRadius(r(8, 8, 184, 284), const Radius.circular(2)),
      line(.5, 1.5),
    );
    canvas.drawLine(
        Offset(8 * sx, 150 * sy), Offset(192 * sx, 150 * sy), line(.45));
    canvas.drawCircle(Offset(100 * sx, 150 * sy), 28 * sx, line(.45));
    canvas.drawCircle(Offset(100 * sx, 150 * sy), 2.5 * sx,
        Paint()..color = Colors.white.withValues(alpha: .6));
    for (final top in [true, false]) {
      canvas.drawRect(r(52, top ? 8 : 246, 96, 46), line(.38));
      canvas.drawRect(r(72, top ? 8 : 272, 56, 20), line(.38));
      canvas.drawRect(r(84, top ? 2 : 291, 32, 7),
          Paint()..color = Colors.white.withValues(alpha: .14));
      canvas.drawRect(r(84, top ? 2 : 291, 32, 7), line(.6, 1.2));
      canvas.drawCircle(Offset(100 * sx, (top ? 36 : 264) * sy), 2 * sx,
          Paint()..color = Colors.white.withValues(alpha: .45));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

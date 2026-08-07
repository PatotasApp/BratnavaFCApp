import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Campo de futebol compartilhado.
///
/// As marcações vinham de um `_FieldPainter` privado do Montar times. Como o
/// dashboard passou a mostrar os times escalados, o desenho virou este widget
/// para não existirem dois campos que divergem com o tempo.
///
/// Diferença em relação ao original: aqui cabem **duas** equipes, uma em cada
/// metade. O Montar times monta um time só e continua usando a mesma pintura.
class FootballPitchPainter extends CustomPainter {
  /// Campo deitado, com os gols à esquerda e à direita.
  ///
  /// A geometria é escrita uma vez só, em pé. Para deitar, giramos o canvas em
  /// 90° e passamos o tamanho invertido — reescrever todas as medidas numa
  /// segunda versão seria a forma garantida de as duas divergirem.
  final bool horizontal;

  const FootballPitchPainter({this.horizontal = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (!horizontal) {
      _paintPortrait(canvas, size);
      return;
    }
    canvas.save();
    // Após transladar e girar, o eixo x local aponta para baixo na tela e o y
    // local para a esquerda: (lx, ly) cai em (w - ly, lx).
    canvas.translate(size.width, 0);
    canvas.rotate(math.pi / 2);
    _paintPortrait(canvas, Size(size.height, size.width));
    canvas.restore();
  }

  void _paintPortrait(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Faixas de grama
    final stripePaint = Paint()..color = AppColors.darkApp.withAlpha(18);
    for (double y = 0; y < h; y += 36) {
      canvas.drawRect(Rect.fromLTWH(0, y + 18, w, 18), stripePaint);
    }

    final linePaint = Paint()
      ..color = AppColors.onDark.withAlpha(140)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final thin = Paint()
      ..color = AppColors.onDark.withAlpha(100)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = AppColors.onDark.withAlpha(40)
      ..style = PaintingStyle.fill;

    const m = 8 / 200; // margem proporcional

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * m, h * (8 / 300), w * (1 - m), h * (292 / 300)),
        const Radius.circular(3),
      ),
      linePaint,
    );

    canvas.drawLine(Offset(w * m, h * 0.5), Offset(w * (1 - m), h * 0.5), thin);
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.14, thin);
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), 2.5, glowPaint);

    final goalFill = Paint()
      ..color = AppColors.onDark.withAlpha(40)
      ..style = PaintingStyle.fill;

    void penaltyBox(double areaTop, double areaBottom, double goalAreaTop,
        double goalAreaBottom, double goalTop, double goalBottom) {
      canvas.drawRect(
        Rect.fromLTRB(
            w * (52 / 200), h * areaTop, w * (148 / 200), h * areaBottom),
        thin,
      );
      canvas.drawRect(
        Rect.fromLTRB(w * (72 / 200), h * goalAreaTop, w * (128 / 200),
            h * goalAreaBottom),
        thin,
      );
      final goal = RRect.fromRectAndRadius(
        Rect.fromLTRB(
            w * (84 / 200), h * goalTop, w * (116 / 200), h * goalBottom),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(goal, goalFill);
      canvas.drawRRect(goal, linePaint);
    }

    penaltyBox(8 / 300, 54 / 300, 8 / 300, 28 / 300, 2 / 300, 9 / 300);
    penaltyBox(
        246 / 300, 292 / 300, 272 / 300, 292 / 300, 291 / 300, 298 / 300);

    canvas.drawCircle(Offset(w * 0.5, h * (36 / 300)), 2.5, glowPaint);
    canvas.drawCircle(Offset(w * 0.5, h * (264 / 300)), 2.5, glowPaint);
  }

  @override
  bool shouldRepaint(covariant FootballPitchPainter oldDelegate) =>
      oldDelegate.horizontal != horizontal;
}

/// Um jogador posicionado no campo.
class PitchPlayer {
  final String name;
  final bool isGoalkeeper;

  /// Usadas só para ordenar a escalação: quem tem mais ataque que defesa vai
  /// para a frente. Sem elas, a ordem da lista é mantida.
  final double? attackRating;
  final double? defenseRating;

  const PitchPlayer({
    required this.name,
    this.isGoalkeeper = false,
    this.attackRating,
    this.defenseRating,
  });
}

/// Posições dos jogadores de linha na metade de cima, por quantidade.
///
/// Copiada do `MatchField` do site (tabela `TOP_OUT`), que é o que o Montar
/// times desenha. O dashboard tinha um distribuidor próprio que dividia a
/// metade em fileiras iguais: com 6 jogadores ele empilhava tudo em duas
/// colunas e os nomes se amontoavam. Não vale ter dois arranjos.
const Map<int, List<Offset>> _topOutfield = {
  0: [],
  1: [Offset(0.50, 0.35)],
  2: [Offset(0.25, 0.35), Offset(0.75, 0.35)],
  3: [Offset(0.50, 0.24), Offset(0.20, 0.38), Offset(0.80, 0.38)],
  4: [
    Offset(0.28, 0.24),
    Offset(0.72, 0.24),
    Offset(0.20, 0.40),
    Offset(0.80, 0.40),
  ],
  5: [
    Offset(0.50, 0.22),
    Offset(0.20, 0.30),
    Offset(0.80, 0.30),
    Offset(0.22, 0.43),
    Offset(0.78, 0.43),
  ],
  6: [
    Offset(0.18, 0.19),
    Offset(0.50, 0.23),
    Offset(0.82, 0.19),
    Offset(0.18, 0.38),
    Offset(0.50, 0.44),
    Offset(0.82, 0.38),
  ],
  7: [
    Offset(0.18, 0.19),
    Offset(0.36, 0.25),
    Offset(0.64, 0.25),
    Offset(0.82, 0.19),
    Offset(0.18, 0.37),
    Offset(0.50, 0.44),
    Offset(0.82, 0.37),
  ],
};

/// Campo com as duas equipes escaladas, cada uma na sua metade.
///
/// Em pé, A fica em cima e B embaixo. Deitado ([horizontal]), A à esquerda e B
/// à direita — é o formato que cabe melhor num card de dashboard, onde a
/// largura sobra e a altura é cara.
///
/// Quando não há times definidos, mostra [emptyMessage] no lugar dos pinos:
/// um campo vazio sem explicação faz parecer que algo falhou ao carregar.
class MatchPitch extends StatelessWidget {
  final List<PitchPlayer> teamA;
  final List<PitchPlayer> teamB;
  final Color teamAColor;
  final Color teamBColor;
  final String teamALabel;
  final String teamBLabel;
  final String? emptyMessage;

  /// Campo deitado: gols nas laterais, times à esquerda e à direita.
  final bool horizontal;

  /// 2/3 é a proporção do Montar times, em pé. Deitado, o padrão inverte.
  final double? aspectRatio;

  const MatchPitch({
    super.key,
    required this.teamA,
    required this.teamB,
    required this.teamAColor,
    required this.teamBColor,
    this.teamALabel = 'Time A',
    this.teamBLabel = 'Time B',
    this.emptyMessage,
    this.horizontal = false,
    this.aspectRatio,
  });

  double get _ratio => aspectRatio ?? (horizontal ? 3 / 2 : 2 / 3);

  bool get _isEmpty => teamA.isEmpty && teamB.isEmpty;

  /// Distribui os jogadores de uma equipe na sua metade.
  ///
  /// `top` = metade de cima (ataca para baixo): goleiro colado na própria
  /// linha de fundo, jogadores de linha avançando para o meio. Para a metade
  /// de baixo a tabela é espelhada em y.
  ///
  /// Mesmo algoritmo do `buildHalf` do site.
  static List<Offset> _layout(List<PitchPlayer> players, {required bool top}) {
    if (players.isEmpty) return const [];

    final result = List<Offset>.filled(players.length, const Offset(0.5, 0.5));

    final gkIdx = players.indexWhere((p) => p.isGoalkeeper);
    if (gkIdx >= 0) result[gkIdx] = Offset(0.5, top ? 0.07 : 0.93);

    final outfield = List.generate(players.length, (i) => i)
        .where((i) => i != gkIdx)
        .toList();
    if (outfield.isEmpty) return result;

    // Acima de 7 na linha os pinos repetem a última posição, como no site.
    final table = _topOutfield[math.min(outfield.length, 7)]!;
    final raw = List.generate(outfield.length, (i) {
      final p = table[math.min(i, table.length - 1)];
      return top ? p : Offset(p.dx, 1 - p.dy);
    });

    final hasRatings = outfield.any((i) =>
        players[i].attackRating != null || players[i].defenseRating != null);

    if (!hasRatings) {
      for (var i = 0; i < outfield.length; i++) {
        result[outfield[i]] = raw[i];
      }
      return result;
    }

    // Com notas, quem tem mais ataque que defesa ocupa as posições mais
    // adiantadas. "Adiantado" é y maior em cima e y menor embaixo.
    final posOrder = List.generate(raw.length, (i) => i)
      ..sort((a, b) => top
          ? raw[b].dy.compareTo(raw[a].dy)
          : raw[a].dy.compareTo(raw[b].dy));

    double bias(int idx) =>
        (players[idx].attackRating ?? 0) - (players[idx].defenseRating ?? 0);

    final playerOrder = List.generate(outfield.length, (i) => i)
      ..sort((a, b) => bias(outfield[b]).compareTo(bias(outfield[a])));

    for (var k = 0; k < playerOrder.length; k++) {
      result[outfield[playerOrder[k]]] = raw[posOrder[k]];
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _ratio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: const [
                    AppColors.primaryPressed,
                    AppColors.primaryPressed,
                    AppColors.primaryPressed,
                  ],
                  // O gradiente acompanha o eixo do campo.
                  begin:
                      horizontal ? Alignment.centerLeft : Alignment.topCenter,
                  end: horizontal
                      ? Alignment.centerRight
                      : Alignment.bottomCenter,
                ),
              ),
            ),
            CustomPaint(
              size: Size.infinite,
              painter: FootballPitchPainter(horizontal: horizontal),
            ),
            if (_isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    emptyMessage ?? 'Times ainda não definidos',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.onDark.withValues(alpha: .85),
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    // O pino é ancorado pelo centro do círculo, então a caixa
                    // do nome passa do retângulo do Stack. Sem isto o Flutter
                    // reclama de overflow — o recorte de verdade, igual ao do
                    // site, é o ClipRRect de fora.
                    clipBehavior: Clip.none,
                    children: [
                      ..._pins(teamA, teamAColor,
                          top: true, size: constraints.biggest),
                      ..._pins(teamB, teamBColor,
                          top: false, size: constraints.biggest),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _pins(List<PitchPlayer> players, Color color,
      {required bool top, required Size size}) {
    final positions = _layout(players, top: top);
    return List.generate(players.length, (i) {
      // Deitado, a metade "de cima" vira a da esquerda. É o mesmo giro de 90°
      // aplicado ao desenho do campo: (x, y) → (y, 1 − x).
      final p = positions[i];
      final pos = horizontal ? Offset(p.dy, 1 - p.dx) : p;

      // O pino é ancorado pelo centro do círculo, não pelo topo da caixa: se
      // fosse pelo topo, um nome de duas linhas empurraria o círculo para
      // cima e o jogador sairia da posição.
      return Positioned(
        left: pos.dx * size.width - _Pin.width / 2,
        top: pos.dy * size.height - _Pin.diameter / 2,
        width: _Pin.width,
        child: _Pin(player: players[i], color: color),
      );
    });
  }
}

/// Pino de jogador, nas medidas do `FieldPin` compacto do Montar times.
class _Pin extends StatelessWidget {
  final PitchPlayer player;
  final Color color;

  /// Largura da caixa do nome. É ela que limita o texto: sem um teto, nomes
  /// compridos se sobrepõem aos dos vizinhos.
  static const double width = 52;
  static const double diameter = 28;

  const _Pin({required this.player, required this.color});

  /// Primeira letra do primeiro e do último nome — "Pedro Roweder" → "PR".
  /// Nome único vira as duas primeiras letras.
  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // Texto preto ou branco conforme a luminância da cor do time: as cores são
    // escolhidas pela patota e podem ser claras (amarelo, branco) ou escuras.
    final light = color.computeLuminance() > 0.5;
    final onColor =
        light ? AppColors.darkApp.withValues(alpha: .82) : AppColors.onDark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: diameter,
          height: diameter,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: light
                  ? AppColors.darkApp.withValues(alpha: .25)
                  : AppColors.onDark.withValues(alpha: .9),
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                  color: AppColors.shadow25,
                  blurRadius: 4,
                  offset: Offset(0, 2)),
            ],
          ),
          child: player.isGoalkeeper
              // Luva, como no Montar times — lá é o emoji 🧤.
              ? const Text('🧤', style: TextStyle(fontSize: 13, height: 1))
              : Text(
                  _initials(player.name),
                  style: TextStyle(
                    fontSize: 9,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: onColor,
                  ),
                ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.darkApp.withValues(alpha: .6),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            player.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.onDark,
              fontSize: 9,
              height: 1.15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

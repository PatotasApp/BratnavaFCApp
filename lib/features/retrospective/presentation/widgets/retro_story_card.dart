import 'package:flutter/material.dart';

import '../../../../core/theme/retro_colors.dart';
import '../../domain/entities/player_retrospective.dart';
import '../../domain/retrospective_stories.dart';

const retroLogoAsset = 'assets/images/logo_icon_source_transparent.png';

class _Palette {
  final Color a, b, fg, ring, blob, line, pill;
  final bool onColor;
  const _Palette(
      this.a, this.b, this.fg, this.ring, this.blob, this.line, this.pill,
      {this.onColor = false});
}

_Palette _paletteOf(StoryTheme t) => switch (t) {
      StoryTheme.green => const _Palette(
          RetroColors.greenA,
          RetroColors.greenB,
          RetroColors.white,
          RetroColors.white07,
          RetroColors.white06,
          RetroColors.white22,
          RetroColors.black28,
          onColor: true),
      StoryTheme.dark => const _Palette(
          RetroColors.darkA,
          RetroColors.darkB,
          RetroColors.white,
          RetroColors.white07,
          RetroColors.white06,
          RetroColors.white22,
          RetroColors.black28),
      StoryTheme.blue => const _Palette(
          RetroColors.blueA,
          RetroColors.blueB,
          RetroColors.white,
          RetroColors.white07,
          RetroColors.white06,
          RetroColors.white22,
          RetroColors.black28),
      StoryTheme.yellow => const _Palette(
          RetroColors.yellowA,
          RetroColors.yellowB,
          RetroColors.ink,
          RetroColors.black07,
          RetroColors.black06,
          RetroColors.black20,
          RetroColors.black14,
          onColor: true),
      StoryTheme.red => const _Palette(
          RetroColors.redA,
          RetroColors.redB,
          RetroColors.white,
          RetroColors.white07,
          RetroColors.white06,
          RetroColors.white22,
          RetroColors.black28),
    };

/// Story 9:16 da Retrospectiva com a marca PatotasApp. Tudo é medido em frações
/// da largura (u = largura/100), então a mesma árvore serve para a tela e para
/// a imagem 1080×1920. [still] desliga a animação de entrada.
class RetroStoryCard extends StatelessWidget {
  final PlayerRetrospective r;
  final StoryMeta story;
  final bool still;

  const RetroStoryCard(
      {super.key, required this.r, required this.story, this.still = false});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: LayoutBuilder(builder: (context, c) {
        final u = c.maxWidth / 100;
        final p = _paletteOf(story.theme);
        // Fonte do tema do app (Poppins).
        final font =
            Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
        final s = _Styles(u, p, font);
        return ClipRect(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(-0.35, -1),
                end: const Alignment(0.35, 1),
                colors: [p.a, p.a, p.b],
                stops: const [0, .55, 1],
              ),
            ),
            child: DefaultTextStyle(
              style: s.base,
              child: Stack(children: [
                Positioned(
                  right: -70 * u,
                  top: -40 * u,
                  child: Container(
                    width: 120 * u,
                    height: 120 * u,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: p.ring, width: 9 * u)),
                  ),
                ),
                Positioned(
                  left: -20 * u,
                  bottom: 10 * u,
                  child: Container(
                    width: 46 * u,
                    height: 46 * u,
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: p.blob),
                  ),
                ),
                Positioned(
                  top: 8 * u,
                  left: 8 * u,
                  right: 8 * u,
                  child: Opacity(
                    opacity: .85,
                    child: Row(children: [
                      Flexible(
                        child: Text('Retrospectiva ${r.period.label}',
                            style: s.tag,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      SizedBox(width: 3 * u),
                      Expanded(
                        child: Text(r.groupName,
                            style: s.tag,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ),
                ),
                Positioned(
                  top: 15 * u,
                  left: 8 * u,
                  right: 8 * u,
                  bottom: 22 * u,
                  child: _Body(r: r, story: story, s: s, still: still),
                ),
                Positioned(
                    left: 8 * u,
                    right: 8 * u,
                    bottom: 7 * u,
                    child: _Brand(r: r, s: s)),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

class _Styles {
  final double u;
  final _Palette p;
  final TextStyle font;
  _Styles(this.u, this.p, this.font);

  static const _tab = [FontFeature.tabularFigures()];

  TextStyle get base => font.copyWith(
      color: p.fg,
      fontSize: 4 * u,
      height: 1.3,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      decoration: TextDecoration.none);
  TextStyle get tag => base.copyWith(
      fontSize: 3.2 * u,
      fontWeight: FontWeight.w600,
      letterSpacing: .04 * 3.2 * u);
  TextStyle get k => base.copyWith(
      fontSize: 3.4 * u,
      fontWeight: FontWeight.w600,
      letterSpacing: .14 * 3.4 * u,
      color: p.fg.withValues(alpha: .78));
  TextStyle get t1 => base.copyWith(
      fontSize: 10 * u,
      fontWeight: FontWeight.w800,
      height: 1.02,
      letterSpacing: -.02 * 10 * u);
  TextStyle get t2 => base.copyWith(
      fontSize: 6.4 * u, fontWeight: FontWeight.w700, height: 1.12);
  TextStyle get p1 => base.copyWith(
      fontSize: 4.3 * u, height: 1.4, color: p.fg.withValues(alpha: .9));
  TextStyle get huge => base.copyWith(
      fontSize: 38 * u,
      fontWeight: FontWeight.w900,
      height: .9,
      letterSpacing: -.04 * 38 * u,
      fontFeatures: _tab);
  TextStyle get mid => base.copyWith(
      fontSize: 24 * u,
      fontWeight: FontWeight.w800,
      height: .95,
      fontFeatures: _tab);
  TextStyle get rowLabel =>
      base.copyWith(fontSize: 4 * u, color: p.fg.withValues(alpha: .85));
  TextStyle get rowValue => base.copyWith(
      fontSize: 6 * u, fontWeight: FontWeight.w800, fontFeatures: _tab);
  TextStyle get pill =>
      base.copyWith(fontSize: 3.8 * u, fontWeight: FontWeight.w600);
}

/// Entrada animada (sobe e aparece), em sequência pelo índice.
class _In extends StatefulWidget {
  final int i;
  final bool still;
  final Widget child;
  const _In(this.i, this.still, this.child);

  @override
  State<_In> createState() => _InState();
}

class _InState extends State<_In> {
  late bool _shown = widget.still;

  @override
  void initState() {
    super.initState();
    if (!_shown) {
      Future.delayed(Duration(milliseconds: 150 + widget.i * 220), () {
        if (mounted) setState(() => _shown = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.still) return widget.child;
    const d = Duration(milliseconds: 600);
    return AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: d,
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _shown ? Offset.zero : const Offset(0, .15),
        duration: d,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final PlayerRetrospective r;
  final StoryMeta story;
  final _Styles s;
  final bool still;

  const _Body(
      {required this.r,
      required this.story,
      required this.s,
      required this.still});

  @override
  Widget build(BuildContext context) {
    final u = s.u;
    final items = _items();
    // Conteúdo maior que a área (nome comprido, muitos marcos) encolhe para caber,
    // em vez de vazar do cartão. O Spacer do perfil empurra o número para baixo.
    return LayoutBuilder(
      builder: (context, c) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: c.maxWidth,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0 && items[i] is! Spacer) SizedBox(height: 3 * u),
                    items[i] is Spacer ? items[i] : _In(i, still, items[i]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _k(String t) => Text(t.toUpperCase(), style: s.k);
  Widget _t1(String t, {double? size}) =>
      Text(t, style: size == null ? s.t1 : s.t1.copyWith(fontSize: size));
  Widget _t2(String t) => Text(t, style: s.t2);
  Widget _p(String t) => Text(t, style: s.p1);
  Widget _huge(Object v) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text('$v', style: s.huge, maxLines: 1),
      );

  Widget _rows(List<(String, String)> rows) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              margin: EdgeInsets.only(top: i == 0 ? 0 : 2.6 * s.u),
              padding: EdgeInsets.only(top: 2.4 * s.u),
              decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: s.p.line))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: Text(rows[i].$1, style: s.rowLabel)),
                SizedBox(width: 3 * s.u),
                // Valor na largura natural, até 60% da linha; passou disso, encolhe.
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 50 * s.u),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(rows[i].$2, style: s.rowValue, maxLines: 1),
                  ),
                ),
              ]),
            ),
        ],
      );

  Widget _pill(String t, {Color? bg}) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding:
              EdgeInsets.symmetric(vertical: 1.8 * s.u, horizontal: 3.6 * s.u),
          decoration: BoxDecoration(
              color: bg ?? s.p.pill,
              borderRadius: BorderRadius.circular(10 * s.u)),
          child: Text(t, style: s.pill),
        ),
      );

  Widget _wdl() {
    final total = r.results == 0 ? 1 : r.results;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3 * s.u),
      child: SizedBox(
        height: 3 * s.u,
        child: ColoredBox(
          color: RetroColors.white15,
          child: Row(children: [
            if (r.wins > 0)
              Expanded(
                  flex: r.wins * 1000 ~/ total,
                  child: const ColoredBox(color: RetroColors.win)),
            if (r.draws > 0)
              Expanded(
                  flex: r.draws * 1000 ~/ total,
                  child: const ColoredBox(color: RetroColors.draw)),
            if (r.losses > 0)
              Expanded(
                  flex: r.losses * 1000 ~/ total,
                  child: const ColoredBox(color: RetroColors.loss)),
          ]),
        ),
      ),
    );
  }

  Widget _months(bool goals) {
    final u = s.u;
    final vals = r.months.map((m) => goals ? m.goals : m.assists).toList();
    final max = vals.fold<int>(1, (a, b) => b > a ? b : a);
    final top = vals.fold<int>(0, (a, b) => b > a ? b : a);
    final yellow = story.theme == StoryTheme.yellow;
    final bar = yellow ? RetroColors.ink22 : RetroColors.white90;
    final topBar = yellow ? RetroColors.ink : RetroColors.yellowA;
    final small =
        s.base.copyWith(fontSize: 2.6 * u, color: s.p.fg.withValues(alpha: .8));
    return SizedBox(
      height: 32 * u,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < vals.length; i++) ...[
          if (i > 0) SizedBox(width: 1.4 * u),
          Expanded(
            child: Builder(builder: (context) {
              final barMax =
                  32 * u - 10 * u; // altura do gráfico menos número e mês
              return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(vals[i] == 0 ? '' : '${vals[i]}',
                        maxLines: 1,
                        style: s.base.copyWith(
                            fontSize: 2.8 * u,
                            fontWeight: FontWeight.w700,
                            height: 1.2)),
                    SizedBox(height: 1 * u),
                    Container(
                      height: (vals[i] / max * barMax).clamp(.6 * u, barMax),
                      decoration: BoxDecoration(
                        color: vals[i] == top && vals[i] > 0 ? topBar : bar,
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(1.4 * u),
                            bottom: Radius.circular(.4 * u)),
                      ),
                    ),
                    SizedBox(height: 1 * u),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                          monthLabel(r, r.months[i].year, r.months[i].month),
                          style: small.copyWith(height: 1.2),
                          maxLines: 1),
                    ),
                  ]);
            }),
          ),
        ],
      ]),
    );
  }

  Widget _vsBox(String label, String name, String sub) {
    final u = s.u;
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(4 * u),
        decoration: BoxDecoration(
            color: RetroColors.black25,
            borderRadius: BorderRadius.circular(4 * u)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _k(label),
          SizedBox(height: 1.6 * u),
          if (name.isNotEmpty)
            Text(name,
                style: s.base.copyWith(
                    fontSize: 6.2 * u,
                    fontWeight: FontWeight.w800,
                    height: 1.05)),
          if (name.isNotEmpty) SizedBox(height: 1.6 * u),
          Text(sub,
              style: s.base.copyWith(
                  fontSize: 3.6 * u,
                  fontWeight: FontWeight.w600,
                  color: s.p.fg.withValues(alpha: .85))),
        ]),
      ),
    );
  }

  List<Widget> _items() {
    final u = s.u;
    final profile = profileOf(r);
    switch (story.id) {
      case StoryId.abertura:
        return [
          _k(r.groupName),
          _t1('${r.player.shortName}, sua temporada ${r.period.label} chegou.'),
          _p('${plural(r.totalGames, 'jogo', 'jogos')} depois, aqui está o que você aprontou em campo.'),
        ];
      case StoryId.presenca:
        return [
          _k('Você entrou em campo'),
          _huge(r.games),
          _t2('${r.games == 1 ? 'vez' : 'vezes'}, de ${r.totalGames} jogos da patota.'),
          _rows([
            ('Presença', '${r.presencePercent}%'),
            if (r.presenceRank != null)
              ('No ranking de presença', rk(r.presenceRank!)),
            (
              'Maior sequência sem faltar',
              plural(r.longestPresenceStreak, 'jogo', 'jogos')
            ),
          ]),
        ];
      case StoryId.resultados:
        return [
          _k('Seu aproveitamento'),
          _huge('${r.aproveitamento}%'),
          _wdl(),
          _rows([
            (
              'Vitórias, empates, derrotas',
              '${r.wins} · ${r.draws} · ${r.losses}'
            ),
            if (r.resultsRank != null) ('No ranking', rk(r.resultsRank!)),
            ('Mais vitórias seguidas', '${r.longestWinStreak}'),
            if (r.bestMonth != null)
              (
                'Seu melhor mês',
                '${retroMeses[r.bestMonth!.month - 1]} · ${recordText(r.bestMonth!.wins, r.bestMonth!.draws, r.bestMonth!.losses)}'
              ),
          ]),
        ];
      case StoryId.gols:
        return [
          _k('Você marcou'),
          _huge(r.goals),
          _t2('${r.goals == 1 ? 'gol' : 'gols'}.${r.goalsRank != null ? ' ${rkSentence(r.goalsRank!)}.' : ''}'),
          if (r.months.isNotEmpty) _months(true),
          if (r.bestGoalNight != null)
            _pill(
                'Melhor noite: ${plural(r.bestGoalNight!.count, 'gol', 'gols')} em ${dayMonth(r.bestGoalNight!.playedAt)}'),
        ];
      case StoryId.assist:
        return [
          _k('Você deu'),
          _huge(r.assists),
          _t2('${r.assists == 1 ? 'assistência' : 'assistências'}.${r.assistsRank != null ? ' ${rkSentence(r.assistsRank!)}.' : ''}'),
          if (r.months.isNotEmpty) _months(false),
          if (r.bestAssistNight != null)
            _pill(
                'Melhor noite: ${plural(r.bestAssistNight!.count, 'assistência', 'assistências')} em ${dayMonth(r.bestAssistNight!.playedAt)}'),
          if (r.mostAssistedTo != null || r.mostAssistedBy != null)
            _rows([
              if (r.mostAssistedTo != null)
                (
                  'Mais recebeu seus passes',
                  '${r.mostAssistedTo!.name} · ${r.mostAssistedTo!.count}'
                ),
              if (r.mostAssistedBy != null)
                (
                  'Seu garçom',
                  '${r.mostAssistedBy!.name} · ${r.mostAssistedBy!.count}'
                ),
            ]),
        ];
      case StoryId.decisivo:
        return [
          _k('Na hora que importa'),
          _t1('Você decide.'),
          _rows([
            ('Vezes que abriu o placar', '${r.openers}'),
            ('Gols da vitória', '${r.winningGoals}')
          ]),
        ];
      case StoryId.parceria:
        final best = r.bestPartner;
        final freq = r.frequentPartner;
        return [
          _k(best != null ? 'Sua dupla de ouro' : 'Seu parceiro de time'),
          if (best != null) ...[
            _t1(best.name),
            _p('Juntos no mesmo time: ${plural(best.games, 'jogo', 'jogos')} e ${best.aproveitamento}% de aproveitamento.'),
          ] else if (freq != null) ...[
            _t1(freq.name),
            _p('Quem mais jogou do seu lado: ${plural(freq.games, 'jogo', 'jogos')} juntos.'),
          ],
          if (best != null && freq != null && freq.playerId != best.playerId)
            _pill(
                'Quem mais jogou do seu lado: ${freq.name} · ${plural(freq.games, 'jogo', 'jogos')}',
                bg: RetroColors.white18),
        ];
      case StoryId.rivais:
        final f = r.fregues;
        final c = r.carrasco;
        return [
          _k('Rivalidades'),
          _t1('Quem você mais venceu e quem mais te venceu.'),
          IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _vsBox(
                  'Seu freguês',
                  f?.name ?? '',
                  f == null
                      ? 'Ninguém ainda'
                      : recordText(f.wins, f.draws, f.losses)),
              SizedBox(width: 3 * u),
              _vsBox(
                  'Seu carrasco',
                  c?.name ?? 'Ninguém',
                  c == null
                      ? 'ninguém levou vantagem sobre você'
                      : recordText(c.wins, c.draws, c.losses)),
            ]),
          ),
        ];
      case StoryId.marcos:
        return [
          _k('Você entrou para a história da patota'),
          _t1('Seus marcos'),
          Column(children: [
            for (final m in r.milestones.take(4)) ...[
              Container(
                margin: EdgeInsets.only(bottom: 2.6 * u),
                padding: EdgeInsets.all(3.4 * u),
                decoration: BoxDecoration(
                    color: RetroColors.black22,
                    borderRadius: BorderRadius.circular(4 * u)),
                child: Row(children: [
                  SizedBox(
                    width: 22 * u,
                    child: Text(
                        milestoneText(m.kind, m.number, r.period.isPartial)
                            .badge,
                        style: s.base.copyWith(
                            fontSize: 8.4 * u,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            color: RetroColors.yellowA)),
                  ),
                  SizedBox(width: 3 * u),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              milestoneText(
                                      m.kind, m.number, r.period.isPartial)
                                  .text,
                              style: s.base.copyWith(
                                  fontSize: 3.9 * u,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3)),
                          Text(dayMonth(m.playedAt),
                              style: s.base.copyWith(
                                  fontSize: 3.2 * u,
                                  color: s.p.fg.withValues(alpha: .7))),
                        ]),
                  ),
                ]),
              ),
            ],
          ]),
        ];
      case StoryId.mvp:
        return [
          _k('A patota votou'),
          _huge(r.mvps),
          _t2('${r.mvps == 1 ? 'vez' : 'vezes'} eleito MVP.'),
          _rows([
            ('Votos recebidos', '${r.mvpVotes}'),
            if (r.mvpRank != null) ('No ranking de MVP', rk(r.mvpRank!)),
          ]),
        ];
      case StoryId.golcontra:
        return [
          _k('E teve aquele momento…'),
          _huge(r.ownGoals),
          _t2('${r.ownGoals == 1 ? 'gol contra' : 'gols contra'}. Membro oficial do Clube do Gol Contra.'),
          _p('Faz parte. Ninguém lembra. (Todo mundo lembra.)'),
        ];
      case StoryId.perfil:
        final pd = profileData(r);
        final long =
            profile.title.length > 10 && !profile.title.contains(' da ');
        return [
          _k('Seu perfil na patota'),
          _t1(profile.title.replaceFirst('O ', 'O '),
              size: (long ? 12.5 : 15) * u),
          _p(profile.tagline),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pd.heroValue, style: s.mid),
            SizedBox(height: 1.4 * u),
            Text(pd.heroLabel, style: s.t2.copyWith(fontSize: 5.6 * u)),
          ]),
          _rows(pd.rows),
        ];
      case StoryId.resumo:
        final big = s.base.copyWith(
            fontSize: 9.6 * u, fontWeight: FontWeight.w800, height: 1);
        final cap = s.base.copyWith(
            fontSize: 3.2 * u,
            fontWeight: FontWeight.w600,
            letterSpacing: .1 * 3.2 * u,
            color: s.p.fg.withValues(alpha: .78));
        Widget cell(String v, String l, {bool name = false}) => Container(
              padding: EdgeInsets.only(top: 2 * u),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: RetroColors.white22))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 9.6 * u,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Text(v,
                            style: name ? big.copyWith(fontSize: 6.4 * u) : big,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    Text(l.toUpperCase(), style: cap),
                  ]),
            );
        Widget pair(Widget a, Widget b) => Padding(
              padding: EdgeInsets.only(bottom: 3.2 * u),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: a),
                SizedBox(width: 4 * u),
                Expanded(child: b),
              ]),
            );
        return [
          _k('${r.groupName} · ${r.period.label}'),
          _t1(r.player.name),
          _pill(profile.title, bg: RetroColors.greenB),
          Column(children: [
            pair(cell('${r.games}', 'jogos'),
                cell('${r.aproveitamento}%', 'aproveitamento')),
            pair(cell('${r.goals}', 'gols'),
                cell('${r.assists}', 'assistências')),
            pair(cell('${r.mvps}', 'MVPs'),
                cell(summaryPartner(r), 'dupla de ouro', name: true)),
          ]),
        ];
    }
  }
}

class _Brand extends StatelessWidget {
  final PlayerRetrospective r;
  final _Styles s;
  const _Brand({required this.r, required this.s});

  @override
  Widget build(BuildContext context) {
    final u = s.u;
    final onColor = s.p.onColor;
    return Row(children: [
      Container(
        width: 9 * u,
        height: 9 * u,
        padding: EdgeInsets.all(.9 * u),
        decoration: BoxDecoration(
            color: RetroColors.white,
            borderRadius: BorderRadius.circular(2.4 * u)),
        child: Image.asset(retroLogoAsset, fit: BoxFit.contain),
      ),
      SizedBox(width: 2.6 * u),
      Expanded(
        flex: 3,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Patotas'),
                  TextSpan(
                    text: 'App',
                    style: onColor
                        ? TextStyle(
                            decoration: TextDecoration.underline,
                            decorationColor: s.p.fg,
                            decorationThickness: 2)
                        : const TextStyle(color: RetroColors.greenB),
                  ),
                ]),
                style: s.base.copyWith(
                    fontSize: 4 * u, fontWeight: FontWeight.w800, height: 1.15),
              ),
              Text('${r.player.shortName} · temporada ${r.period.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: s.base.copyWith(
                      fontSize: 3 * u,
                      height: 1.15,
                      color: s.p.fg.withValues(alpha: .78))),
            ]),
      ),
      Flexible(
        flex: 2,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text('patotasapp.com.br',
              style: s.base.copyWith(
                  fontSize: 3 * u,
                  fontWeight: FontWeight.w600,
                  color: s.p.fg.withValues(alpha: .85))),
        ),
      ),
    ]);
  }
}

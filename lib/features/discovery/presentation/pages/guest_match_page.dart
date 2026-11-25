import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/prototype_ui.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../matches/domain/entities/match_models.dart';
import '../../../matches/presentation/widgets/match_stepper_header.dart';
import '../../data/discovery_datasource.dart';
import '../../domain/discovery_models.dart';

/// Partida vista por quem foi aceito como convidado de fora da patota.
///
/// Segue o visual da tela de Partidas (cabeçalho de etapas, faixa pontilhada,
/// placar e times lado a lado), mas é só leitura: a única ação é o "Vou" /
/// "Não vou" enquanto a partida ainda está em aceitação. Atualiza sozinha a
/// cada 20 s e ao puxar a tela, já que quem está de fora não participa do tempo
/// real da patota.
class GuestMatchPage extends ConsumerStatefulWidget {
  const GuestMatchPage({super.key, required this.matchId});
  final String matchId;

  @override
  ConsumerState<GuestMatchPage> createState() => _GuestMatchPageState();
}

class _GuestMatchPageState extends ConsumerState<GuestMatchPage> {
  GuestMatch? _match;
  String? _error;
  bool _accessDenied = false;
  bool _loading = true;
  bool _saving = false;
  Timer? _timer;

  DiscoveryDataSource get _api => DiscoveryDataSource(ref.read(dioProvider));

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final match = await _api.guestMatch(widget.matchId);
      if (!mounted) return;
      setState(() {
        _match = match;
        _error = null;
        _accessDenied = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final status = e is DioException ? e.response?.statusCode : null;
      final accessDenied = status == 403 || status == 404;
      setState(() {
        // Mantém o que já estava na tela se for só uma falha de rede.
        _error = _match == null
            ? accessDenied
                ? 'Você não tem acesso aos dados desta partida. '
                    'Eles ficam disponíveis para quem jogou.'
                : 'Não foi possível carregar a partida. Verifique sua conexão.'
            : null;
        _accessDenied = accessDenied;
        _loading = false;
      });
    }
  }

  Future<void> _answer(bool going) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    try {
      final match = await _api.setGuestAttendance(widget.matchId, going);
      if (!mounted) return;
      setState(() => _match = match);
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(going
              ? 'Presença confirmada. Bom jogo!'
              : 'Ok, avisamos a patota que você não vai.'),
        ));
    } catch (_) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: errorColor,
          content: const Text(
              'Não foi possível salvar. A partida pode já ter começado.'),
        ));
      await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _match;
    return Scaffold(
      appBar: AppBar(title: Text(m?.groupName ?? 'Partida')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: m == null
                  ? ListView(padding: const EdgeInsets.all(32), children: [
                      Icon(
                        _accessDenied
                            ? Icons.lock_outline_rounded
                            : Icons.cloud_off_outlined,
                        size: 44,
                      ),
                      const SizedBox(height: 12),
                      Text(_error ?? 'Partida não encontrada.',
                          textAlign: TextAlign.center),
                      if (!_accessDenied) ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() => _loading = true);
                            _load();
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Tentar novamente'),
                        ),
                      ],
                    ])
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 32),
                      children: [
                        MatchStepperHeader(
                          currentStep: MatchStep.fromStatus(m.matchStatus),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _InfoBand(match: m),
                              if (m.canChangeAttendance) ...[
                                const SizedBox(height: 12),
                                _AttendanceCard(
                                  response: m.myResponse,
                                  saving: _saving,
                                  onAnswer: _answer,
                                ),
                              ],
                              if (m.matchStatus >= 3 &&
                                  m.teamAGoals != null &&
                                  m.teamBGoals != null) ...[
                                const SizedBox(height: 12),
                                _Scoreboard(match: m),
                              ],
                              const SizedBox(height: 16),
                              _Teams(match: m),
                              if (m.matchStatus >= 4) ...[
                                const SizedBox(height: 16),
                                _ResultSection(match: m),
                              ],
                              const SizedBox(height: 18),
                              Text(
                                'Você acompanha esta partida como convidado. '
                                'Só a patota pode alterar times e resultado.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: context.appTextSecondary,
                                    ),
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

// ── Cores ───────────────────────────────────────────────────────────────────

Color _teamColor(BuildContext context, GuestMatchColor? c, int team) {
  final hex = (c?.hexValue ?? '').replaceAll('#', '');
  final parsed = hex.length == 6 ? int.tryParse(hex, radix: 16) : null;
  if (parsed != null) return Color(0xFF000000 | parsed);
  final scheme = Theme.of(context).colorScheme;
  return team == 1 ? scheme.primary : scheme.tertiary;
}

String _teamName(GuestMatchColor? c, int team) =>
    (c?.name ?? '').trim().isNotEmpty
        ? c!.name
        : (team == 1 ? 'Time A' : 'Time B');

// ── Faixa de informações ────────────────────────────────────────────────────

class _InfoBand extends StatelessWidget {
  const _InfoBand({required this.match});
  final GuestMatch match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date =
        DateFormat("EEEE, dd 'de' MMMM", 'pt_BR').format(match.playedAt);
    final time = DateFormat('HH:mm').format(match.playedAt);
    final (label, tone) = switch (match.myResponse) {
      'going' => ('Confirmado', PrototypeBadgeTone.success),
      'waiting' => ('Lista de espera', PrototypeBadgeTone.accent),
      'not_going' => ('Você não vai', PrototypeBadgeTone.danger),
      _ => ('Aguardando você', PrototypeBadgeTone.accent),
    };
    return PrototypeHeaderBand(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PrototypeIconBox(
                icon: Icon(Icons.sports_soccer_rounded),
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONVIDADO EM',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        color: context.appTextSecondary,
                      ),
                    ),
                    Text(
                      match.groupName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PrototypeBadge(label: label, tone: tone),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            toBeginningOfSentenceCase(date) ?? date,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.3),
          ),
          const SizedBox(height: 2),
          Text(
            time,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.primary,
              height: 1.1,
            ),
          ),
          if ((match.placeName ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.place_outlined,
                  size: 16, color: context.appTextSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(match.placeName!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: context.appTextSecondary)),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

// ── Vou / Não vou ───────────────────────────────────────────────────────────

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({
    required this.response,
    required this.saving,
    required this.onAnswer,
  });
  final String response;
  final bool saving;
  final Future<void> Function(bool going) onAnswer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final going = response == 'going';
    final waiting = response == 'waiting';
    final notGoing = response == 'not_going';
    return PrototypeCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            going
                ? 'Presença confirmada'
                : waiting
                    ? 'Você está na lista de espera'
                    : notGoing
                        ? 'Você avisou que não vai'
                        : 'Você vai jogar?',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            waiting
                ? 'Se uma vaga abrir, sua presença será confirmada automaticamente e você receberá uma notificação.'
                : 'Dá para mudar de ideia até a patota fechar as confirmações.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: context.appTextSecondary),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _ChoiceButton(
                label: waiting ? 'Sair da fila' : 'Não vou',
                icon: Icons.close_rounded,
                selected: notGoing,
                color: theme.colorScheme.error,
                onPressed: saving || notGoing ? null : () => onAnswer(false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ChoiceButton(
                label: waiting ? 'Na fila' : 'Vou',
                icon:
                    waiting ? Icons.hourglass_top_rounded : Icons.check_rounded,
                selected: going || waiting,
                color: theme.colorScheme.primary,
                loading: saving,
                onPressed:
                    saving || going || waiting ? null : () => onAnswer(true),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onPressed,
    this.loading = false,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox.square(
            dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          );
    const shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)));
    const size = Size.fromHeight(52);
    return selected
        ? FilledButton(
            onPressed: null,
            style: FilledButton.styleFrom(
              minimumSize: size,
              shape: shape,
              disabledBackgroundColor: color.withValues(alpha: .16),
              disabledForegroundColor: color,
            ),
            child: child,
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: size,
              shape: shape,
              foregroundColor: color,
              side: BorderSide(color: color.withValues(alpha: .5)),
            ),
            child: child,
          );
  }
}

// ── Placar ──────────────────────────────────────────────────────────────────

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.match});
  final GuestMatch match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = match.teamAGoals!, b = match.teamBGoals!;
    final live = match.matchStatus == 3;
    return PrototypeHeaderBand(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (live) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                live ? 'AO VIVO' : 'PLACAR',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ScoreSide(
                  name: _teamName(match.teamAColor, 1),
                  goals: a,
                  color: _teamColor(context, match.teamAColor, 1),
                  leading: a >= b,
                ),
              ),
              Text('×',
                  style: theme.textTheme.headlineMedium?.copyWith(
                      color: context.appTextSecondary,
                      fontWeight: FontWeight.w300)),
              Expanded(
                child: _ScoreSide(
                  name: _teamName(match.teamBColor, 2),
                  goals: b,
                  color: _teamColor(context, match.teamBColor, 2),
                  leading: b >= a,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreSide extends StatelessWidget {
  const _ScoreSide({
    required this.name,
    required this.goals,
    required this.color,
    required this.leading,
  });
  final String name;
  final int goals;
  final Color color;
  final bool leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$goals',
          style: theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1,
            color: leading
                ? theme.colorScheme.onSurface
                : context.appTextSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

// ── Times ───────────────────────────────────────────────────────────────────

class _Teams extends StatelessWidget {
  const _Teams({required this.match});
  final GuestMatch match;

  @override
  Widget build(BuildContext context) {
    final a = match.players.where((p) => p.team == 1).toList();
    final b = match.players.where((p) => p.team == 2).toList();
    final rest =
        match.players.where((p) => p.team != 1 && p.team != 2).toList();
    final formed = a.isNotEmpty || b.isNotEmpty;

    if (match.players.isEmpty) {
      return PrototypeCard(
        child: Text(
          'Ninguém confirmou presença ainda.',
          style: TextStyle(color: context.appTextSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrototypeSectionTitle(
          title: formed ? 'Times' : 'Confirmados',
          count: '${match.players.length}',
        ),
        const SizedBox(height: 10),
        if (formed)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _TeamColumn(
                  name: _teamName(match.teamAColor, 1),
                  color: _teamColor(context, match.teamAColor, 1),
                  players: a,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TeamColumn(
                  name: _teamName(match.teamBColor, 2),
                  color: _teamColor(context, match.teamBColor, 2),
                  players: b,
                ),
              ),
            ],
          ),
        if (formed && rest.isNotEmpty) const SizedBox(height: 10),
        if (rest.isNotEmpty)
          PrototypeCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (formed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'SEM TIME · ${rest.length}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final p in rest) _PlayerChip(player: p)],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({
    required this.name,
    required this.color,
    required this.players,
  });
  final String name;
  final Color color;
  final List<GuestMatchPlayer> players;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(PrototypeLayout.cardRadius),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PrototypeLayout.cardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: .28),
                    color.withValues(alpha: .06)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(bottom: BorderSide(color: color, width: 3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text('${players.length}',
                      style: theme.textTheme.labelLarge?.copyWith(
                          color: context.appTextSecondary,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  if (players.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text('Sem jogadores',
                          style: TextStyle(color: context.appTextSecondary)),
                    ),
                  for (final p in players)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _PlayerTile(player: p, teamColor: color),
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

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.player, required this.teamColor});
  final GuestMatchPlayer player;
  final Color teamColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = player.isMe;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: me
            ? theme.colorScheme.primaryContainer.withValues(alpha: .55)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: me ? theme.colorScheme.primary : AppColors.transparent,
          width: 1.4,
        ),
      ),
      child: Row(
        children: [
          AvatarWidget(
            name: player.name,
            photoUrl: player.photoUrl,
            size: 30,
            borderRadius: 10,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: me ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
                if (me)
                  Text(
                    'VOCÊ',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
              ],
            ),
          ),
          if (player.isMvp)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child:
                  Icon(Icons.star_rounded, size: 18, color: AppColors.amber500),
            ),
          if (player.isGoalkeeper)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.sports_handball_rounded,
                  size: 16, color: context.appTextSecondary),
            ),
        ],
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({required this.player});
  final GuestMatchPlayer player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = player.isMe;
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
      decoration: BoxDecoration(
        color: me
            ? theme.colorScheme.primaryContainer.withValues(alpha: .55)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color:
              me ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AvatarWidget(
            name: player.name,
            photoUrl: player.photoUrl,
            size: 26,
            borderRadius: 13,
          ),
          const SizedBox(width: 7),
          Text(
            me ? '${player.name} · você' : player.name,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: me ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
          if (player.isGoalkeeper) ...[
            const SizedBox(width: 5),
            Icon(Icons.sports_handball_rounded,
                size: 14, color: context.appTextSecondary),
          ],
        ],
      ),
    );
  }
}

// ── Resultado: MVP, números e gols ──────────────────────────────────────────

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.match});
  final GuestMatch match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mvps = match.players.where((p) => p.isMvp).toList();
    final showGoals = match.goalsVisible;
    if (mvps.isEmpty && !showGoals) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PrototypeSectionTitle(title: 'Resultado'),
        const SizedBox(height: 10),
        if (mvps.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.warning, AppColors.amber500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(PrototypeLayout.cardRadius),
              boxShadow: [
                BoxShadow(
                  color: AppColors.warning.withValues(alpha: .35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded,
                    color: AppColors.onDark, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MVP DA PARTIDA',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.onDark,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w900,
                          )),
                      Text(
                        mvps
                            .map((p) => p.isMe ? '${p.name} (você)' : p.name)
                            .join(', '),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.onDark,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (showGoals && match.myGoals != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _StatTile(
                  label: 'Seus gols',
                  value: '${match.myGoals}',
                  icon: Icons.sports_soccer_rounded),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                  label: 'Suas assistências',
                  value: '${match.myAssists ?? 0}',
                  icon: Icons.handshake_outlined),
            ),
          ]),
        ],
        if (showGoals && match.goals.isNotEmpty) ...[
          const SizedBox(height: 10),
          PrototypeCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GOLS',
                    style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.4, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                for (final g in match.goals) _GoalRow(match: match, goal: g),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label, value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PrototypeCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          PrototypeIconBox(icon: Icon(icon), size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900, height: 1)),
                const SizedBox(height: 2),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: context.appTextSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.match, required this.goal});
  final GuestMatch match;
  final GuestMatchGoal goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _teamColor(
      context,
      goal.team == 2 ? match.teamBColor : match.teamAColor,
      goal.team == 2 ? 2 : 1,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .18),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.6),
            ),
            child: Icon(Icons.sports_soccer_rounded, size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.ownGoal ? '${goal.scorer} (contra)' : goal.scorer,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (goal.assist != null)
                  Text('assistência de ${goal.assist}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: context.appTextSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

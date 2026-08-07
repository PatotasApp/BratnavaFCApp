import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/horizontal_team_field.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../domain/entities/current_match.dart';
import '../../../matches/domain/entities/match_models.dart' show matchStepLabel;

class CurrentMatchCard extends StatefulWidget {
  final CurrentMatch match;
  final String playerId;

  const CurrentMatchCard({
    super.key,
    required this.match,
    required this.playerId,
  });

  @override
  State<CurrentMatchCard> createState() => _CurrentMatchCardState();
}

class _CurrentMatchCardState extends State<CurrentMatchCard> {
  bool _showField = false;

  @override
  void didUpdateWidget(CurrentMatchCard old) {
    super.didUpdateWidget(old);
    if (old.match.matchId != widget.match.matchId) {
      _showField = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dates = _formatDate(match.playedAt);

    final found =
        widget.playerId.isNotEmpty ? _findPlayer(match, widget.playerId) : null;
    final isAssigned = found != null && found.team != 0;
    final isUnassigned = found != null && found.team == 0;

    final teamAPlayers = match.players.where((p) => p.team == 1).toList();
    final teamBPlayers = match.players.where((p) => p.team == 2).toList();
    final teamACount = teamAPlayers.length;
    final teamBCount = teamBPlayers.length;

    final showPlayerNames =
        match.stepKey == 'teams' || match.stepKey == 'playing';
    final visibleTeamAPlayers = showPlayerNames
        ? teamAPlayers.where((p) => p.playerName.isNotEmpty).toList()
        : <MatchPlayer>[];
    final visibleTeamBPlayers = showPlayerNames
        ? teamBPlayers.where((p) => p.playerName.isNotEmpty).toList()
        : <MatchPlayer>[];

    final hasScore =
        match.teamAGoals > 0 || match.teamBGoals > 0 || match.status >= 4;

    // Show "Ver times" footer when teams are fully set
    final canShowField =
        showPlayerNames && teamAPlayers.isNotEmpty && teamBPlayers.isNotEmpty;

    // Build FieldPlayer lists from MatchPlayer
    final fieldA = teamAPlayers
        .map((p) => FieldPlayer(
            id: p.playerId, name: p.playerName, isGoalkeeper: p.isGoalkeeper))
        .toList();
    final fieldB = teamBPlayers
        .map((p) => FieldPlayer(
            id: p.playerId, name: p.playerName, isGoalkeeper: p.isGoalkeeper))
        .toList();

    final aColor = _parseHex(match.teamAColor?.hexValue) ?? AppColors.blue500;
    final bColor = _parseHex(match.teamBColor?.hexValue) ?? AppColors.slate400;

    return GestureDetector(
      onTap: () => context.go('/app/matches'),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : AppColors.onDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? AppColors.slate700 : AppColors.slate200),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header escuro: data completa + badge de status ───────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppColors.slate900,
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      size: 14, color: AppColors.slate400),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      dates.full,
                      style: const TextStyle(
                        color: AppColors.onDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(text: matchStepLabel(match.statusName)),
                ],
              ),
            ),

            // ── Corpo ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Esquerda: local + times + placar
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Local
                        if (match.placeName.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 14,
                                  color: isDark
                                      ? AppColors.slate500
                                      : AppColors.slate400),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  match.placeName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? AppColors.slate400
                                        : AppColors.slate600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Times
                        Row(
                          children: [
                            Flexible(
                                child: _TeamBlock(
                                    color: match.teamAColor,
                                    label: 'Time A',
                                    count: teamACount,
                                    isDark: isDark,
                                    groupId: match.groupId,
                                    players: visibleTeamAPlayers)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                'VS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.slate600
                                      : AppColors.slate300,
                                ),
                              ),
                            ),
                            Flexible(
                                child: _TeamBlock(
                                    color: match.teamBColor,
                                    label: 'Time B',
                                    count: teamBCount,
                                    isDark: isDark,
                                    groupId: match.groupId,
                                    players: visibleTeamBPlayers)),
                          ],
                        ),

                        // Placar
                        if (hasScore) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text(
                                'Placar:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.slate400
                                      : AppColors.slate500,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.slate700
                                      : AppColors.slate900,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${match.teamAGoals}',
                                      style: const TextStyle(
                                        color: AppColors.onDark,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 4),
                                      child: Text('×',
                                          style: TextStyle(
                                              color: AppColors.slate500,
                                              fontSize: 12)),
                                    ),
                                    Text(
                                      '${match.teamBGoals}',
                                      style: const TextStyle(
                                        color: AppColors.onDark,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Direita: situação do jogador
                  if (widget.playerId.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Container(
                      width: 1,
                      height: 80,
                      color: isDark ? AppColors.slate800 : AppColors.slate100,
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 140,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sua situação',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.slate500
                                  : AppColors.slate400,
                              letterSpacing: .3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (found == null)
                            Text(
                              'Não está nesta partida.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.slate400
                                    : AppColors.slate500,
                              ),
                            )
                          else if (isUnassigned) ...[
                            Text(
                              'Aguardando alocação de time.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.slate400
                                    : AppColors.slate500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _InviteBadge(response: found.inviteResponse),
                          ] else if (isAssigned) ...[
                            _MiniShirt(
                              hex:
                                  _teamColor(match, found.team)?.hexValue ?? '',
                              label: 'Time ${found.team == 1 ? "A" : "B"}'
                                  ' · ${_teamColor(match, found.team)?.name ?? "—"}',
                            ),
                            const SizedBox(height: 6),
                            _InviteBadge(response: found.inviteResponse),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Footer: Ver times ──────────────────────────────────────────
            if (canShowField) ...[
              Divider(
                height: 1,
                color: isDark ? AppColors.slate800 : AppColors.slate100,
              ),
              GestureDetector(
                onTap: () => setState(() => _showField = !_showField),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _showField
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: isDark ? AppColors.slate400 : AppColors.slate500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showField ? 'Ocultar times' : 'Ver times',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color:
                              isDark ? AppColors.slate400 : AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Campo expandido ──────────────────────────────────────────
              if (_showField)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: HorizontalTeamField(
                    teamA: fieldA,
                    teamB: fieldB,
                    teamAColor: aColor,
                    teamBColor: bColor,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static MatchPlayer? _findPlayer(CurrentMatch m, String pid) {
    try {
      return m.players.firstWhere((p) => p.playerId == pid);
    } catch (_) {
      return null;
    }
  }

  static TeamColor? _teamColor(CurrentMatch m, int team) =>
      team == 1 ? m.teamAColor : m.teamBColor;

  static ({String full}) _formatDate(DateTime d) {
    final full = DateFormat("EEE, dd MMM yyyy 'às' HH:mm", 'pt_BR').format(d);
    return (full: full);
  }
}

// ── StatusBadge ───────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String text;
  const _StatusBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    final s = text.toLowerCase();
    Color bg, fg, border;

    if (s.contains('final') || s.contains('done') || s.contains('encer')) {
      bg = AppColors.emerald50;
      fg = AppColors.emerald700;
      border = AppColors.emerald200;
    } else if (s.contains('jog') || s.contains('play') || s.contains('live')) {
      bg = AppColors.blue50;
      fg = AppColors.infoLight;
      border = AppColors.blue200;
    } else if (s.contains('time') || s.contains('match')) {
      bg = AppColors.violet50;
      fg = AppColors.violet700;
      border = AppColors.violet200;
    } else if (s.contains('aceit') || s.contains('accept')) {
      bg = AppColors.amber50;
      fg = AppColors.amber500;
      border = AppColors.amber200;
    } else if (s.contains('pós') || s.contains('pos') || s.contains('post')) {
      bg = AppColors.amber50;
      fg = AppColors.warningLight;
      border = AppColors.amber200;
    } else {
      bg = AppColors.slate50;
      fg = AppColors.slate600;
      border = AppColors.slate200;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ── InviteBadge ───────────────────────────────────────────────────────────────

class _InviteBadge extends StatelessWidget {
  final InviteResponse response;
  const _InviteBadge({required this.response});

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg, border) = switch (response) {
      InviteResponse.accepted => (
          'Confirmado ✓',
          AppColors.emerald700,
          AppColors.emerald50,
          AppColors.emerald200
        ),
      InviteResponse.declined => (
          'Recusado',
          AppColors.rose600,
          AppColors.rose50,
          AppColors.rose200
        ),
      _ => (
          'Pendente',
          AppColors.amber500,
          AppColors.amber50,
          AppColors.amber200
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ── ColorDot ─────────────────────────────────────────────────────────────────

class _ColorDot extends StatelessWidget {
  final String? hex;
  final bool large;
  const _ColorDot({this.hex, this.large = false});

  @override
  Widget build(BuildContext context) {
    final size = large ? 20.0 : 14.0;
    final color = _parseHex(hex);
    if (color == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.slate700
              : AppColors.slate200,
        ),
      );
    }
    final isWhite = (hex ?? '').toLowerCase().replaceAll('#', '') == 'ffffff';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: isWhite
              ? AppColors.slate300
              : AppColors.onDark.withValues(alpha: .3),
          width: 1,
        ),
      ),
    );
  }
}

Color? _parseHex(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  try {
    return Color(int.parse('0xFF${hex.replaceAll('#', '')}'));
  } catch (_) {
    return null;
  }
}

// ── TeamBlock ─────────────────────────────────────────────────────────────────

class _TeamBlock extends StatelessWidget {
  final TeamColor? color;
  final String label;
  final int count;
  final bool isDark;
  final String groupId;
  final List<MatchPlayer> players;

  const _TeamBlock({
    this.color,
    required this.label,
    required this.count,
    required this.isDark,
    required this.groupId,
    this.players = const [],
  });

  @override
  Widget build(BuildContext context) {
    final showPlayers = players.isNotEmpty;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ColorDot(hex: color?.hexValue, large: true),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                color?.name ?? label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.slate300 : AppColors.slate700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              if (showPlayers)
                ...players.map((player) => Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: ConfiguredPlayerName(
                        groupId: groupId,
                        name: player.playerName,
                        isGoalkeeper: player.isGoalkeeper,
                        iconSize: 11,
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              isDark ? AppColors.slate400 : AppColors.slate500,
                        ),
                      ),
                    ))
              else
                Text(
                  '$count jogador${count != 1 ? "es" : ""}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.slate500 : AppColors.slate400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── MiniShirt ─────────────────────────────────────────────────────────────────

class _MiniShirt extends StatelessWidget {
  final String hex;
  final String label;
  const _MiniShirt({required this.hex, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = _parseHex(hex) ?? AppColors.slate400;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: .35),
                  blurRadius: 4,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Icon(Icons.sports_soccer,
              size: 14, color: AppColors.onDark.withValues(alpha: .8)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

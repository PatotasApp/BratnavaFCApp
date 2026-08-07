/// GroupIconRenderer
///
/// Widget compartilhado que renderiza ícones configuráveis por patota,
/// espelhando o IconRenderer.tsx do site.
///
/// Formatos suportados:
///   "⚽"            → emoji / caractere
///   "lucide:Trophy" → ícone Material mapeado
///   "letter:G"      → texto em negrito estilizado
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/group_settings/domain/entities/group_settings.dart';
import '../../../features/group_settings/presentation/providers/group_settings_provider.dart';

// ── Mapeamento lucide → Material ──────────────────────────────────────────────

const kGroupLucideIcons = <String, IconData>{
  'Trophy': Icons.emoji_events_outlined,
  'User': Icons.person_outline,
  'Target': Icons.gps_fixed,
  'Medal': Icons.military_tech_outlined,
  'ShieldAlert': Icons.shield_outlined,
  'Radar': Icons.radar,
  'Link': Icons.link_outlined,
  'Handshake': Icons.handshake_outlined,
  'AlertTriangle': Icons.warning_amber_outlined,
  'Ban': Icons.block_outlined,
  'Award': Icons.workspace_premium_outlined,
  'Crown': Icons.workspace_premium_outlined,
  'UserRound': Icons.account_circle_outlined,
  'Shirt': Icons.dry_cleaning_outlined,
};

// ── Função de renderização ────────────────────────────────────────────────────

/// Renderiza um valor de ícone de grupo (emoji, lucide:Nome, ou letter:Texto).
/// Equivalente ao IconRenderer.tsx do site.
Widget renderGroupIcon(String value, {double size = 14, Color? color}) {
  if (value.startsWith('lucide:')) {
    final name = value.substring(7);
    final data = kGroupLucideIcons[name];
    if (data != null) return Icon(data, size: size, color: color);
    return Text('?', style: TextStyle(fontSize: size * 0.8, color: color));
  }
  if (value.startsWith('letter:')) {
    final text = value.substring(7);
    final scale = text.length <= 2
        ? 0.85
        : text.length == 3
            ? 0.72
            : 0.60;
    return Text(
      text,
      style: TextStyle(
        fontSize: size * scale,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1,
        color: color,
      ),
    );
  }
  // Emoji ou caractere comum
  return Text(value, style: TextStyle(fontSize: size));
}

// ── Classe de ícones resolvidos ───────────────────────────────────────────────

/// Ícones resolvidos de uma patota, com defaults idênticos ao site.
class GroupIcons {
  final String goal;
  final String goalkeeper;
  final String assist;
  final String ownGoal;
  final String mvp;
  final String player;
  final String rank1;
  final String rank2;
  final String rank3;

  const GroupIcons({
    required this.goal,
    required this.goalkeeper,
    required this.assist,
    required this.ownGoal,
    required this.mvp,
    required this.player,
    required this.rank1,
    required this.rank2,
    required this.rank3,
  });

  /// Defaults (sem configuração salva)
  static const defaults = GroupIcons(
    goal: '⚽',
    goalkeeper: '🧤',
    assist: '🤝',
    ownGoal: '🚩',
    mvp: 'lucide:Trophy',
    player: 'lucide:User',
    rank1: '🥇',
    rank2: '🥈',
    rank3: '🥉',
  );

  /// Resolve a partir de um [GroupSettings] carregado da API.
  factory GroupIcons.from(GroupSettings? s) => GroupIcons(
        goal: s?.goalIcon ?? '⚽',
        goalkeeper: s?.goalkeeperIcon ?? '🧤',
        assist: s?.assistIcon ?? '🤝',
        ownGoal: s?.ownGoalIcon ?? '🚩',
        mvp: s?.mvpIcon ?? 'lucide:Trophy',
        player: s?.playerIcon ?? 'lucide:User',
        rank1: s?.rank1Icon ?? '🥇',
        rank2: s?.rank2Icon ?? '🥈',
        rank3: s?.rank3Icon ?? '🥉',
      );
}

/// Nome de jogador sempre acompanhado pelo ícone configurado da patota.
class ConfiguredPlayerName extends ConsumerWidget {
  final String groupId;
  final String name;
  final bool isGoalkeeper;
  final double iconSize;
  final TextStyle? style;
  final int maxLines;

  const ConfiguredPlayerName({
    super.key,
    required this.groupId,
    required this.name,
    this.isGoalkeeper = false,
    this.iconSize = 14,
    this.style,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = groupId.isEmpty
        ? null
        : ref.watch(groupSettingsProvider(groupId)).valueOrNull;
    final icons = GroupIcons.from(settings);
    final resolvedStyle = style ?? Theme.of(context).textTheme.bodyLarge;

    return PlayerNameWithIcon(
      name: name,
      isGoalkeeper: isGoalkeeper,
      icons: icons,
      iconSize: iconSize,
      style: resolvedStyle,
      maxLines: maxLines,
    );
  }
}

class PlayerNameWithIcon extends StatelessWidget {
  final String name;
  final bool isGoalkeeper;
  final GroupIcons icons;
  final double iconSize;
  final TextStyle? style;
  final int maxLines;

  const PlayerNameWithIcon({
    super.key,
    required this.name,
    required this.icons,
    this.isGoalkeeper = false,
    this.iconSize = 14,
    this.style,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = style ?? Theme.of(context).textTheme.bodyLarge;
    final icon = isGoalkeeper ? icons.goalkeeper : icons.player;
    final nameWidget = Text(
      name,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: resolvedStyle,
    );

    // DataTable mede suas células por dimensões intrínsecas; LayoutBuilder
    // não oferece esse cálculo e quebra a renderização da tabela.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        nameWidget,
        const SizedBox(width: 5),
        renderGroupIcon(
          icon,
          size: iconSize,
          color: resolvedStyle?.color,
        ),
      ],
    );
  }
}

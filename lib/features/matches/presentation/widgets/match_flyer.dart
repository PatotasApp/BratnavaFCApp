import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/entities/match_models.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

Future<void> showMatchCardDialog({
  required BuildContext context,
  required MatchState s,
  required String groupId,
  required Dio dio,
}) async {
  await showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _MatchCardDialog(s: s, groupId: groupId, dio: dio),
  );
}

// ── Prompt builder (mirrors MatchCardService.BuildPrompt in C#) ───────────────

String buildMatchCardPrompt(MatchState s) {
  final buf = StringBuffer();

  final playedAt = s.playedAt;
  final dateStr = playedAt != null ? _fmtDate(playedAt) : '';

  final aName = s.teamAColor?.name ?? 'Time A';
  final bName = s.teamBColor?.name ?? 'Time B';
  final aHex = s.teamAColor?.hexValue ?? '#334155';
  final bHex = s.teamBColor?.hexValue ?? '#334155';

  buf.writeln(
      'You are editing a soccer match card image. You MUST keep the EXACT same layout, style, fonts, stadium background, Bratnava logo, jersey design, \'icone\' text on jerseys, and overall design from the template image.');
  buf.writeln(
      'Only change: (1) text content, (2) jersey/shirt colors, (3) player names in the panels.');
  buf.writeln();
  buf.writeln('=== CARD TYPE: MATCH PREVIEW ===');
  if (dateStr.isNotEmpty) buf.writeln('Date text: $dateStr');

  void writeTeam(
      String side, String name, String hex, List<MatchPlayerInfo> players) {
    buf.writeln();
    buf.writeln('=== $side TEAM ===');
    buf.writeln('Jersey color: $hex ($name)');
    buf.writeln('Panel header: TIME ${name.toUpperCase()}');
    buf.writeln(
        'Player list (write each name on its own row inside the panel, in this EXACT order):');
    final ordered = [...players]
      ..sort((a, b) => (b.isGoalkeeper ? 1 : 0) - (a.isGoalkeeper ? 1 : 0));
    for (var i = 0; i < ordered.length; i++) {
      final p = ordered[i];
      final role = p.isGoalkeeper ? 'GOALKEEPER' : 'PLAYER';
      final icon =
          p.isGoalkeeper ? 'goal net icon (🥅)' : 'soccer ball icon (⚽)';
      buf.writeln('  Row ${i + 1}: $icon ${p.playerName}  [$role]');
    }
  }

  writeTeam('LEFT', aName, aHex, s.teamAPlayers);
  writeTeam('RIGHT', bName, bHex, s.teamBPlayers);

  buf.writeln();
  buf.writeln('=== CRITICAL RULES ===');
  buf.writeln(
      '1. PLAYER ORDER: Goalkeepers MUST be the FIRST row in each team panel. Use 🥅 icon for goalkeepers, ⚽ icon for regular players.');
  buf.writeln(
      '2. Each row must show: [icon] [Player Name] — the icon on the left, then the player\'s name as text NEXT to it on the same row. Do NOT put the icon on a separate row from the name.');
  buf.writeln(
      '3. SPELLING: Write each player name EXACTLY as listed above. No changes, no typos, no abbreviations.');
  buf.writeln(
      '4. JERSEY COLORS: Fill the left jersey with $aHex and the right jersey with $bHex. Keep the same shirt shape, \'icone\' text, and Bratnava badge.');
  buf.writeln(
      '5. PANEL COLORS: The left panel header background should match the left jersey color. The right panel header background should match the right jersey color.');
  buf.writeln(
      '6. BACKGROUND: Keep the stadium background blurred exactly as in the template.');
  buf.writeln('7. LOGO: Keep the Bratnava logo at the top exactly as it is.');
  buf.writeln(
      '8. EMPTY ROWS: If there are fewer players than rows in the template, leave the remaining rows empty (just the divider lines, no text).');
  buf.writeln(
      '9. OUTPUT: Portrait image, 1080x1350 pixels, suitable for Instagram.');

  return buf.toString();
}

String _fmtDate(DateTime dt) {
  final local = dt;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);

  String prefix;
  if (day == today) {
    prefix = 'Hoje';
  } else if (day == today.add(const Duration(days: 1))) {
    prefix = 'Amanhã';
  } else {
    prefix = DateFormat("d 'de' MMMM", 'pt_BR').format(local);
  }
  final year = local.year != now.year ? ', ${local.year}' : '';
  final time = DateFormat('HH:mm').format(local);
  return '$prefix$year - $time';
}

// ── Dialog ────────────────────────────────────────────────────────────────────

class _MatchCardDialog extends StatefulWidget {
  final MatchState s;
  final String groupId;
  final Dio dio;
  const _MatchCardDialog(
      {required this.s, required this.groupId, required this.dio});

  @override
  State<_MatchCardDialog> createState() => _MatchCardDialogState();
}

class _MatchCardDialogState extends State<_MatchCardDialog> {
  late final String _prompt = buildMatchCardPrompt(widget.s);
  bool _promptCopied = false;
  bool _generating = false;
  String? _imageBase64;
  String? _error;

  Future<void> _copyPrompt() async {
    await Clipboard.setData(ClipboardData(text: _prompt));
    setState(() => _promptCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _promptCopied = false);
    });
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
      _imageBase64 = null;
    });
    try {
      final aName = widget.s.teamAColor?.name ?? 'Time A';
      final bName = widget.s.teamBColor?.name ?? 'Time B';
      final aHex = widget.s.teamAColor?.hexValue ?? '#334155';
      final bHex = widget.s.teamBColor?.hexValue ?? '#334155';

      final res = await widget.dio.post(
        '/api/MatchCard/group/${widget.groupId}/generate',
        data: {
          'template': 'match_preview',
          'teamAName': aName,
          'teamAColorHex': aHex,
          'teamAPlayers': widget.s.teamAPlayers
              .map((p) => {
                    'name': p.playerName,
                    'isGoalkeeper': p.isGoalkeeper,
                  })
              .toList(),
          'teamBName': bName,
          'teamBColorHex': bHex,
          'teamBPlayers': widget.s.teamBPlayers
              .map((p) => {
                    'name': p.playerName,
                    'isGoalkeeper': p.isGoalkeeper,
                  })
              .toList(),
          'playedAt': widget.s.playedAt?.toIso8601String(),
        },
      );

      final data = res.data;
      final b64 = (data is Map ? data['data'] : null) as String?;
      if (b64 != null && b64.isNotEmpty) {
        setState(() => _imageBase64 = b64);
      } else {
        setState(() =>
            _error = (data is Map ? data['error'] : null) ?? 'Resposta vazia.');
      }
    } catch (e) {
      setState(() => _error = e is DioException
          ? (e.response?.data is Map
              ? e.response?.data['error'] ?? e.message
              : e.message)
          : e.toString());
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _shareImage() async {
    if (_imageBase64 == null) return;
    final bytes = base64Decode(_imageBase64!);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/bratnava_card.png');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Escalação BratnavaFC');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(children: [
                const Icon(Icons.image_outlined, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Card da Partida',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ]),
            ),

            const Divider(height: 16),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Imagem gerada ────────────────────────────────────
                    if (_imageBase64 != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(base64Decode(_imageBase64!)),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _shareImage,
                            icon: const Icon(Icons.share_rounded, size: 16),
                            label: const Text('Compartilhar'),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                    ],

                    // ── Prompt ───────────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: isDark ? Colors.white12 : Colors.black12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Barra do prompt
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color:
                                  isDark ? Colors.white10 : Colors.grey.shade50,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(11)),
                            ),
                            child: Row(children: [
                              Expanded(
                                child: Text(
                                  'Prompt para DALL-E / Midjourney',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _copyPrompt,
                                icon: Icon(
                                  _promptCopied
                                      ? Icons.check_rounded
                                      : Icons.copy_rounded,
                                  size: 14,
                                ),
                                label: Text(
                                  _promptCopied ? 'Copiado!' : 'Copiar',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: _promptCopied
                                      ? Colors.green
                                      : Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ]),
                          ),
                          // Texto do prompt
                          Container(
                            padding: const EdgeInsets.all(10),
                            constraints: const BoxConstraints(maxHeight: 160),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                _prompt,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey.shade800,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Erro ─────────────────────────────────────────────
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(_error!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.red)),
                      ),

                    if (_error != null) const SizedBox(height: 8),

                    // ── Botão gerar ──────────────────────────────────────
                    FilledButton.icon(
                      onPressed: _generating ? null : _generate,
                      icon: _generating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: Text(_generating
                          ? 'Gerando com IA…'
                          : _imageBase64 != null
                              ? 'Gerar novamente'
                              : 'Gerar imagem com IA'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

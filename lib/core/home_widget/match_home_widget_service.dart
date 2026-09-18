import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../../features/matches/domain/entities/match_models.dart';

/// Mantém o widget Android "Partida da Patota" sincronizado com a patota ativa.
///
/// O Android renderiza o widget nativamente; o Flutter apenas persiste um
/// retrato pequeno da partida sempre que os dados do app são atualizados.
class MatchHomeWidgetService {
  MatchHomeWidgetService._();

  static const _androidProvider = 'MatchHomeWidgetProvider';

  static Future<void> sync({
    required UpcomingMatchDetails? match,
    required String playerId,
    required String groupName,
  }) async {
    if (match == null) {
      await _saveAll({
        'match_widget_state': 'empty',
        'match_widget_group_name': groupName,
        'match_widget_title': 'Nenhuma partida agendada',
        'match_widget_subtitle':
            'Abra o PatotasApp para acompanhar sua patota.',
        'match_widget_response': 'Abra o app para ver as próximas partidas',
        'match_widget_confirmed': '',
        'match_widget_match_id': '',
        'match_widget_group_id': '',
      });
      await _update();
      return;
    }

    final header = match.header;
    final step = header.step;
    final isLive = step == MatchStep.playing;
    final isAfterMatch = step == MatchStep.ended ||
        step == MatchStep.post ||
        step == MatchStep.done;
    final isTeams = step == MatchStep.teams;
    final teamACount = match.allPlayers.where((p) => p.team == 1).length;
    final teamBCount = match.allPlayers.where((p) => p.team == 2).length;
    final teamsReady = isTeams && teamACount > 0 && teamBCount > 0;
    final date =
        DateFormat("EEE, dd/MM 'às' HH:mm", 'pt_BR').format(header.playedAt);
    final place = header.placeName.trim();
    final metadata = place.isEmpty ? date : '$date · $place';

    final mine = match.allPlayers.where((p) => p.playerId == playerId);
    final response =
        mine.isEmpty ? InviteResponse.pending : mine.first.inviteResponse;
    final inviteResponseText = switch (response) {
      InviteResponse.accepted => 'Presença confirmada',
      InviteResponse.declined => 'Você não vai',
      InviteResponse.pending => 'Aguardando sua resposta',
    };
    final myTeam = mine.isEmpty ? 0 : mine.first.team;
    final myTeamName = switch (myTeam) {
      1 => _teamName(match.teamAColor, 'Time A'),
      2 => _teamName(match.teamBColor, 'Time B'),
      _ => 'A definir',
    };
    final responseText =
        teamsReady ? 'Seu time: $myTeamName' : inviteResponseText;

    final state = isLive
        ? 'live'
        : isAfterMatch
            ? 'score'
            : teamsReady
                ? 'lineup'
                : isTeams
                    ? 'teams'
                    : 'upcoming';
    final title = isLive
        ? 'AO VIVO'
        : isAfterMatch
            ? (step == MatchStep.post ? 'Pós-jogo' : 'Placar final')
            : teamsReady
                ? 'Times definidos'
                : isTeams
                    ? 'Times em formação'
                    : 'Próxima partida';
    final subtitle = metadata;

    await _saveAll({
      'match_widget_state': state,
      'match_widget_group_name':
          groupName.trim().isEmpty ? 'PatotasApp' : groupName.trim(),
      'match_widget_title': title,
      'match_widget_subtitle': subtitle,
      'match_widget_response': responseText,
      'match_widget_confirmed': teamsReady
          ? '$teamACount no ${_teamName(match.teamAColor, 'Time A')} · '
              '$teamBCount no ${_teamName(match.teamBColor, 'Time B')}'
          : '${match.acceptedCount} confirmados',
      'match_widget_team_a': _teamName(match.teamAColor, 'Time A'),
      'match_widget_team_b': _teamName(match.teamBColor, 'Time B'),
      'match_widget_team_a_color':
          _safeHex(match.teamAColor?.hexValue, '#3CB043'),
      'match_widget_team_b_color':
          _safeHex(match.teamBColor?.hexValue, '#D64545'),
      'match_widget_score_a': '${header.teamAGoals ?? 0}',
      'match_widget_score_b': '${header.teamBGoals ?? 0}',
      'match_widget_match_id': header.matchId,
      'match_widget_group_id': header.groupId,
    });
    await _update();
  }

  static Future<void> clear() async {
    await _saveAll({
      'match_widget_state': 'empty',
      'match_widget_group_name': 'PatotasApp',
      'match_widget_title': 'Entre para acompanhar sua partida',
      'match_widget_subtitle': 'Toque para abrir o aplicativo.',
      'match_widget_response': 'Sua sessão foi encerrada',
      'match_widget_confirmed': '',
      'match_widget_match_id': '',
      'match_widget_group_id': '',
    });
    await _update();
  }

  /// Remove do widget qualquer partida da patota que deixou de estar ativa.
  /// Diferente de [clear], não afirma que a sessão foi encerrada.
  static Future<void> clearActiveGroup() async {
    await _saveAll({
      'match_widget_state': 'empty',
      'match_widget_group_name': 'PatotasApp',
      'match_widget_title': 'Nenhuma patota ativa',
      'match_widget_subtitle': 'Abra o app para selecionar uma patota.',
      'match_widget_response': 'Nenhuma partida para acompanhar',
      'match_widget_confirmed': '',
      'match_widget_match_id': '',
      'match_widget_group_id': '',
    });
    await _update();
  }

  static String _teamName(TeamColorInfo? color, String fallback) {
    final name = color?.name.trim() ?? '';
    return name.isEmpty ? fallback : name;
  }

  static String _safeHex(String? value, String fallback) {
    final raw = value?.trim() ?? '';
    if (RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(raw)) {
      return raw.startsWith('#') ? raw : '#$raw';
    }
    return fallback;
  }

  static Future<void> _saveAll(Map<String, String> data) async {
    await Future.wait(
      data.entries.map(
        (entry) => HomeWidget.saveWidgetData<String>(entry.key, entry.value),
      ),
    );
  }

  static Future<void> _update() => HomeWidget.updateWidget(
        androidName: _androidProvider,
        qualifiedAndroidName: 'br.com.patotasapp.$_androidProvider',
      );
}

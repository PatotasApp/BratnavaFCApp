import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_constants.dart';
import '../constants/app_constants.dart';

// ─── IDs das ações — partida ──────────────────────────────────────────────────

const _kActionAccept = 'match_accept';
const _kActionReject = 'match_reject';
const _kCategoryMatchInvite = 'MATCH_INVITE';

// ─── IDs das ações — poll de evento ──────────────────────────────────────────

const _kPollActionSim    = 'poll_sim';
const _kPollActionTalvez = 'poll_talvez';
const _kPollActionNao    = 'poll_nao';
const _kCategoryEventPoll = 'EVENT_POLL';

// ─── Canais Android ───────────────────────────────────────────────────────────

const _channelId        = 'bratnavafc_high';
const _channelName      = 'BratnavaFC';
const _channelDesc      = 'Notificações do BratnavaFC';

const _inviteChannelId   = 'bratnavafc_match_invite';
const _inviteChannelName = 'Convites de Partida';
const _inviteChannelDesc = 'Convites para participar de partidas';

const _pollChannelId   = 'bratnavafc_event_poll';
const _pollChannelName = 'Votações de Evento';
const _pollChannelDesc = 'Lembretes de votação com botões de resposta rápida';

// ─── Handler de background (top-level obrigatório) ───────────────────────────

/// Chamado quando o usuário toca em SIM/NÃO (partida) ou SIM/TALVEZ/NÃO (poll)
/// com o app em background ou terminado.
@pragma('vm:entry-point')
Future<void> onNotificationActionBackground(NotificationResponse response) async {
  final actionId = response.actionId;
  if (actionId == null) return;

  final parts = response.payload?.split('::') ?? [];

  // ── Ação de partida ─────────────────────────────────────────────────────
  if (actionId == _kActionAccept || actionId == _kActionReject) {
    if (parts.length < 2) return;
    final groupId = parts[0];
    final matchId = parts[1];

    final accessToken = await _readAccessToken();
    if (accessToken == null) return;

    final isAccept = actionId == _kActionAccept;
    final path     = isAccept
        ? ApiConstants.matchMyInviteAccept(groupId, matchId)
        : ApiConstants.matchMyInviteReject(groupId, matchId);

    await _callApi('PATCH', path, null, accessToken);
    return;
  }

  // ── Ação de poll de evento ───────────────────────────────────────────────
  // Payload: "groupId::pollId::optionSimId::optionTalvezId::optionNaoId"
  if (actionId == _kPollActionSim ||
      actionId == _kPollActionTalvez ||
      actionId == _kPollActionNao) {
    if (parts.length < 5) return;
    final groupId      = parts[0];
    final pollId       = parts[1];
    final optionSimId  = parts[2];
    final optionTalvez = parts[3];
    final optionNaoId  = parts[4];

    final optionId = switch (actionId) {
      _kPollActionSim    => optionSimId,
      _kPollActionTalvez => optionTalvez,
      _kPollActionNao    => optionNaoId,
      _                  => null,
    };
    if (optionId == null) return;

    final accessToken = await _readAccessToken();
    if (accessToken == null) return;

    final path = ApiConstants.castVote(groupId, pollId);
    final body = jsonEncode({ 'optionIds': [optionId] });
    await _callApi('POST', path, body, accessToken);
  }
}

// ─── Helpers internos ─────────────────────────────────────────────────────────

Future<String?> _readAccessToken() async {
  try {
    final prefs    = await SharedPreferences.getInstance();
    final raw      = prefs.getString(AppConstants.accountsStorageKey);
    final activeId = prefs.getString(AppConstants.activeAccountKey);
    if (raw == null) return null;

    final accounts = jsonDecode(raw) as List;
    final account  = accounts.firstWhere(
      (a) => a['userId'] == activeId,
      orElse: () => accounts.first,
    ) as Map<String, dynamic>;
    return account['accessToken'] as String?;
  } catch (_) {
    return null;
  }
}

Future<void> _callApi(String method, String path, String? body, String token) async {
  try {
    final client  = HttpClient();
    final uri     = Uri.parse('${AppConstants.apiUrl}$path');
    final request = await client.openUrl(method, uri);
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    if (body != null) {
      final bytes = utf8.encode(body);
      request.contentLength = bytes.length;
      request.add(bytes);
    } else {
      request.contentLength = 0;
    }
    final resp = await request.close();
    client.close();
    // ignore: avoid_print
    print('[Push Action] $method $path — HTTP ${resp.statusCode}');
  } catch (e) {
    // ignore: avoid_print
    print('[Push Action] Erro ao chamar API: $e');
  }
}

// ─── Classe principal ─────────────────────────────────────────────────────────

/// Gerencia notificações locais usadas para exibir mensagens FCM
/// quando o app está em foreground (Android não exibe o banner do sistema).
class LocalNotifications {
  LocalNotifications._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static int  _nextId = 0;

  /// Callback chamado quando o usuário toca no corpo do convite de partida.
  static void Function(String groupId, String matchId)? onMatchInviteTapped;

  /// Callback chamado quando o usuário toca no corpo do lembrete de poll de evento.
  static void Function(String groupId, String pollId)? onEventPollTapped;

  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  /// Handler para foreground/background (isolate principal).
  /// Faz a chamada à API E navega se o usuário tocou no corpo da notificação.
  static void _onForegroundResponse(NotificationResponse response) {
    final actionId = response.actionId;
    final parts    = response.payload?.split('::') ?? [];

    final isMatchAction = actionId == _kActionAccept || actionId == _kActionReject;
    final isPollAction  = actionId == _kPollActionSim ||
                          actionId == _kPollActionTalvez ||
                          actionId == _kPollActionNao;

    if (isMatchAction || isPollAction) {
      // Ação direta → chama API sem abrir o app (mesmo fluxo do background)
      onNotificationActionBackground(response);
    } else if (parts.length >= 2) {
      // Toque no corpo → navega para a tela correta
      if (parts.length >= 5) {
        // Poll de evento: groupId::pollId::...
        onEventPollTapped?.call(parts[0], parts[1]);
      } else {
        // Convite de partida: groupId::matchId
        onMatchInviteTapped?.call(parts[0], parts[1]);
      }
    }
  }

  /// Inicializa o plugin. Chamar uma vez no `main()` antes de `runApp`.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    const android = AndroidInitializationSettings('@drawable/ic_notification');

    // Categoria iOS para convites de partida com botões SIM / NÃO
    final ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          _kCategoryMatchInvite,
          actions: [
            DarwinNotificationAction.plain(_kActionAccept, 'SIM ✅'),
            DarwinNotificationAction.plain(
              _kActionReject,
              'NÃO ❌',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.destructive,
              },
            ),
          ],
        ),
        DarwinNotificationCategory(
          _kCategoryEventPoll,
          actions: [
            DarwinNotificationAction.plain(_kPollActionSim,    'Sim ✅'),
            DarwinNotificationAction.plain(_kPollActionTalvez, 'Talvez 🤷'),
            DarwinNotificationAction.plain(
              _kPollActionNao,
              'Não ❌',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.destructive,
              },
            ),
          ],
        ),
      ],
    );

    await _plugin.initialize(
      InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse:           _onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse: onNotificationActionBackground,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // Canal padrão (alta prioridade)
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      playSound: true,
    ));

    // Canal dedicado para convites com botões de ação
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      _inviteChannelId,
      _inviteChannelName,
      description: _inviteChannelDesc,
      importance: Importance.high,
      playSound: true,
    ));

    // Canal dedicado para polls de evento com botões Sim/Talvez/Não
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      _pollChannelId,
      _pollChannelName,
      description: _pollChannelDesc,
      importance: Importance.high,
      playSound: true,
    ));
  }

  // ── Notificação simples (foreground) ────────────────────────────────────────

  static Future<void> show({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority:   Priority.high,
      playSound:  true,
      icon:       '@drawable/ic_notification',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      _nextId++,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  // ── Notificação de poll de evento com botões Sim / Talvez / Não ────────────

  /// Exibe notificação local com botões de resposta rápida para polls de evento.
  ///
  /// Payload: "groupId::pollId::optionSimId::optionTalvezId::optionNaoId"
  static Future<void> showEventPollReminder({
    required String title,
    required String body,
    required String groupId,
    required String pollId,
    required String optionSimId,
    required String optionTalvezId,
    required String optionNaoId,
  }) async {
    final payload = '$groupId::$pollId::$optionSimId::$optionTalvezId::$optionNaoId';

    final androidDetails = AndroidNotificationDetails(
      _pollChannelId,
      _pollChannelName,
      channelDescription: _pollChannelDesc,
      importance: Importance.high,
      priority:   Priority.high,
      playSound:  true,
      icon:       '@drawable/ic_notification',
      actions: const [
        AndroidNotificationAction(
          _kPollActionSim,
          'Sim ✅',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          _kPollActionTalvez,
          'Talvez 🤷',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          _kPollActionNao,
          'Não ❌',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert:       true,
      presentBadge:       true,
      presentSound:       true,
      categoryIdentifier: _kCategoryEventPoll,
    );

    await _plugin.show(
      _nextId++,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  // ── Notificação de convite de partida com botões SIM / NÃO ─────────────────

  static Future<void> showMatchInvite({
    required String title,
    required String body,
    required String groupId,
    required String matchId,
  }) async {
    final payload = '$groupId::$matchId';

    final androidDetails = AndroidNotificationDetails(
      _inviteChannelId,
      _inviteChannelName,
      channelDescription: _inviteChannelDesc,
      importance: Importance.high,
      priority:   Priority.high,
      playSound:  true,
      icon:       '@drawable/ic_notification',
      actions: const [
        AndroidNotificationAction(
          _kActionAccept,
          'SIM ✅',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          _kActionReject,
          'NÃO ❌',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert:         true,
      presentBadge:         true,
      presentSound:         true,
      categoryIdentifier:   _kCategoryMatchInvite,
    );

    await _plugin.show(
      _nextId++,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }
}

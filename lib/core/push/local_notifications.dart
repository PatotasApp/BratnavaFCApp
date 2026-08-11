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

const _kPollActionSim = 'poll_sim';
const _kPollActionTalvez = 'poll_talvez';
const _kPollActionNao = 'poll_nao';
const _kCategoryEventPoll = 'EVENT_POLL';

// ─── Canais Android ───────────────────────────────────────────────────────────

const _channelId = 'bratnavafc_high';
const _channelName = 'PatotasApp';
const _channelDesc = 'Notificações do PatotasApp';

const _inviteChannelId = 'bratnavafc_match_invite';
const _inviteChannelName = 'Partidas';
const _inviteChannelDesc = 'Convites e confirmações de presença em partidas';

const _pollChannelId = 'bratnavafc_event_poll';
const _pollChannelName = 'Votações de Evento';
const _pollChannelDesc = 'Lembretes de votação com botões de resposta rápida';

// ─── Handler de background (top-level obrigatório) ───────────────────────────

/// Chamado quando o usuário toca em SIM/NÃO (partida) ou SIM/TALVEZ/NÃO (poll)
/// com o app em background ou terminado.
@pragma('vm:entry-point')
Future<void> onNotificationActionBackground(
    NotificationResponse response) async {
  final actionId = response.actionId;
  if (actionId == null) return;

  final parts = response.payload?.split('::') ?? [];

  // ── Ação de partida ─────────────────────────────────────────────────────
  if (actionId == _kActionAccept || actionId == _kActionReject) {
    if (parts.length < 2) return;
    final groupId = parts[0];
    final matchId = parts[1];

    final session = await _readStoredSession();
    if (session == null) return;

    final isAccept = actionId == _kActionAccept;
    final path = isAccept
        ? ApiConstants.matchMyInviteAccept(groupId, matchId)
        : ApiConstants.matchMyInviteReject(groupId, matchId);

    final succeeded = await _callAuthorizedApi(
      method: 'PATCH',
      path: path,
      session: session,
    );
    if (succeeded) await _cancelHandledNotification(response.id);
    return;
  }

  // ── Ação de poll de evento ───────────────────────────────────────────────
  // Payload: "groupId::pollId::optionSimId::optionTalvezId::optionNaoId"
  if (actionId == _kPollActionSim ||
      actionId == _kPollActionTalvez ||
      actionId == _kPollActionNao) {
    if (parts.length < 5) return;
    final groupId = parts[0];
    final pollId = parts[1];
    final optionSimId = parts[2];
    final optionTalvez = parts[3];
    final optionNaoId = parts[4];

    final optionId = switch (actionId) {
      _kPollActionSim => optionSimId,
      _kPollActionTalvez => optionTalvez,
      _kPollActionNao => optionNaoId,
      _ => null,
    };
    if (optionId == null) return;

    final session = await _readStoredSession();
    if (session == null) return;

    final path = ApiConstants.castVote(groupId, pollId);
    final body = jsonEncode({
      'optionIds': [optionId]
    });
    final succeeded = await _callAuthorizedApi(
      method: 'POST',
      path: path,
      body: body,
      session: session,
    );
    if (succeeded) await _cancelHandledNotification(response.id);
  }
}

// ─── Helpers internos ─────────────────────────────────────────────────────────

class _StoredPushSession {
  const _StoredPushSession({
    required this.preferences,
    required this.accounts,
    required this.accountIndex,
  });

  final SharedPreferences preferences;
  final List<Map<String, dynamic>> accounts;
  final int accountIndex;

  Map<String, dynamic> get account => accounts[accountIndex];
  String? get accessToken => account['accessToken'] as String?;
  String? get refreshToken => account['refreshToken'] as String?;

  Future<void> updateTokens(String accessToken, String refreshToken) async {
    account['accessToken'] = accessToken;
    account['refreshToken'] = refreshToken;
    await preferences.setString(
      AppConstants.accountsStorageKey,
      jsonEncode(accounts),
    );
  }
}

class _PushHttpResponse {
  const _PushHttpResponse(this.statusCode, this.body);

  final int statusCode;
  final String body;

  bool get succeeded => statusCode >= 200 && statusCode < 300;
}

Future<_StoredPushSession?> _readStoredSession() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(AppConstants.accountsStorageKey);
    final activeId = prefs.getString(AppConstants.activeAccountKey);
    if (raw == null) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! List || decoded.isEmpty) return null;
    final accounts = decoded
        .whereType<Map>()
        .map((item) => item.map(
              (key, value) => MapEntry(key.toString(), value),
            ))
        .toList();
    if (accounts.isEmpty) return null;

    final activeIndex = accounts.indexWhere(
      (account) => account['userId']?.toString() == activeId,
    );
    final session = _StoredPushSession(
      preferences: prefs,
      accounts: accounts,
      accountIndex: activeIndex >= 0 ? activeIndex : 0,
    );
    if (session.accessToken == null || session.accessToken!.isEmpty) {
      return null;
    }
    return session;
  } catch (_) {
    return null;
  }
}

Future<bool> _callAuthorizedApi({
  required String method,
  required String path,
  required _StoredPushSession session,
  String? body,
}) async {
  var response = await _callApi(method, path, body, session.accessToken!);

  if (response?.statusCode == HttpStatus.unauthorized) {
    final refreshed = await _refreshPushSession(session);
    if (refreshed) {
      response = await _callApi(method, path, body, session.accessToken!);
    }
  }

  final succeeded = response?.succeeded ?? false;
  // ignore: avoid_print
  print(
    '[Push Action] $method $path: '
    '${succeeded ? 'success' : 'failure'} '
    '(HTTP ${response?.statusCode ?? 'no response'})',
  );
  return succeeded;
}

Future<bool> _refreshPushSession(_StoredPushSession session) async {
  final refreshToken = session.refreshToken;
  if (refreshToken == null || refreshToken.isEmpty) return false;

  final response = await _callApi(
    'POST',
    ApiConstants.refreshToken,
    jsonEncode({'refreshToken': refreshToken}),
    '',
  );
  if (response == null || !response.succeeded) return false;

  try {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return false;
    final envelope = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final rawData = envelope['data'] ?? envelope;
    if (rawData is! Map) return false;
    final data = rawData.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final access =
        (data['token'] ?? data['accessToken'] ?? data['jwt'])?.toString();
    final refresh = (data['refreshToken'] ?? data['refresh'])?.toString();
    if (access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty) {
      return false;
    }
    await session.updateTokens(access, refresh);
    return true;
  } catch (_) {
    return false;
  }
}

Future<_PushHttpResponse?> _callApi(
    String method, String path, String? body, String token) async {
  HttpClient? client;
  try {
    client = HttpClient()
      ..connectionTimeout = AppConstants.connectTimeout
      ..idleTimeout = AppConstants.receiveTimeout;
    final uri = Uri.parse('${AppConstants.apiUrl}$path');
    final request = await client.openUrl(method, uri);
    if (token.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    if (body != null) {
      final bytes = utf8.encode(body);
      request.contentLength = bytes.length;
      request.add(bytes);
    } else {
      request.contentLength = 0;
    }
    final resp = await request.close();
    final responseBody = await utf8.decoder.bind(resp).join();
    return _PushHttpResponse(resp.statusCode, responseBody);
  } catch (e) {
    // ignore: avoid_print
    print('[Push Action] Erro ao chamar API: $e');
    return null;
  } finally {
    client?.close(force: true);
  }
}

Future<void> _cancelHandledNotification(int? notificationId) async {
  if (notificationId == null) return;
  await LocalNotifications.plugin.cancel(notificationId);
}

// ─── Classe principal ─────────────────────────────────────────────────────────

/// Gerencia notificações locais usadas para exibir mensagens FCM
/// quando o app está em foreground (Android não exibe o banner do sistema).
class LocalNotifications {
  LocalNotifications._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static int _nextId = 0;

  /// Callback chamado quando o usuário toca no corpo do convite de partida.
  static void Function(String groupId, String matchId)? onMatchInviteTapped;

  /// Callback chamado quando o usuário toca no corpo do lembrete de poll de evento.
  static void Function(String groupId, String pollId)? onEventPollTapped;

  /// Callback para notificações locais comuns exibidas com o app aberto.
  static void Function(Map<String, dynamic> data)? onNotificationTapped;

  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  /// Handler para foreground/background (isolate principal).
  /// Faz a chamada à API E navega se o usuário tocou no corpo da notificação.
  static void _onForegroundResponse(NotificationResponse response) {
    final actionId = response.actionId;
    final parts = response.payload?.split('::') ?? [];

    final isMatchAction =
        actionId == _kActionAccept || actionId == _kActionReject;
    final isPollAction = actionId == _kPollActionSim ||
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
    } else {
      final payload = response.payload;
      if (payload == null || payload.isEmpty) return;
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map) {
          onNotificationTapped?.call(
            decoded.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
      } catch (_) {
        // Payloads de versões antigas podem não estar em JSON.
      }
    }
  }

  /// Inicializa o plugin. Chamar uma vez no `main()` antes de `runApp`.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    const android = AndroidInitializationSettings('@drawable/ic_notification');

    // Categoria iOS para convites de partida com ações de presença.
    final ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          _kCategoryMatchInvite,
          actions: [
            DarwinNotificationAction.plain(_kActionAccept, 'Confirmar'),
            DarwinNotificationAction.plain(
              _kActionReject,
              'Não vou',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.destructive,
              },
            ),
          ],
        ),
        DarwinNotificationCategory(
          _kCategoryEventPoll,
          actions: [
            DarwinNotificationAction.plain(_kPollActionSim, 'Sim ✅'),
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
      onDidReceiveNotificationResponse: _onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse:
          onNotificationActionBackground,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Canal padrão (alta prioridade)
    await androidPlugin
        ?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      playSound: true,
    ));

    // Canal dedicado para convites com botões de ação
    await androidPlugin
        ?.createNotificationChannel(const AndroidNotificationChannel(
      _inviteChannelId,
      _inviteChannelName,
      description: _inviteChannelDesc,
      importance: Importance.high,
      playSound: true,
    ));

    // Canal dedicado para polls de evento com botões Sim/Talvez/Não
    await androidPlugin
        ?.createNotificationChannel(const AndroidNotificationChannel(
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
    Map<String, dynamic>? data,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      icon: '@drawable/ic_notification',
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
      payload: data == null ? null : jsonEncode(data),
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
    final payload =
        '$groupId::$pollId::$optionSimId::$optionTalvezId::$optionNaoId';

    const androidDetails = AndroidNotificationDetails(
      _pollChannelId,
      _pollChannelName,
      channelDescription: _pollChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      icon: '@drawable/ic_notification',
      actions: [
        AndroidNotificationAction(
          _kPollActionSim,
          'Sim ✅',
          showsUserInterface: false,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          _kPollActionTalvez,
          'Talvez 🤷',
          showsUserInterface: false,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          _kPollActionNao,
          'Não ❌',
          showsUserInterface: false,
          cancelNotification: false,
        ),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: _kCategoryEventPoll,
    );

    await _plugin.show(
      _nextId++,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  // ── Notificação de convite de partida com ações de presença ────────────────

  static Future<void> showMatchInvite({
    required String title,
    required String body,
    required String groupId,
    required String matchId,
  }) async {
    final payload = '$groupId::$matchId';

    const androidDetails = AndroidNotificationDetails(
      _inviteChannelId,
      _inviteChannelName,
      channelDescription: _inviteChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      icon: '@drawable/ic_notification',
      actions: [
        AndroidNotificationAction(
          _kActionAccept,
          'Confirmar',
          showsUserInterface: false,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          _kActionReject,
          'Não vou',
          showsUserInterface: false,
          cancelNotification: false,
        ),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: _kCategoryMatchInvite,
    );

    await _plugin.show(
      _nextId++,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }
}

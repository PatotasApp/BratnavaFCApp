import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'local_notifications.dart';
import 'notification_router.dart';
import 'push_token_api.dart';

/// Handler de background — DEVE ser função top-level (fora de qualquer classe).
/// Chamado quando o app está terminado ou em background.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  final log = Logger();
  final data = message.data;
  log.d('[Push BG] type=${data["type"]} | data: $data');

  await LocalNotifications.initialize();

  // O convite é data-only para permitir ações de presença na notificação.
  if (data['type'] == 'match_invite') {
    await LocalNotifications.showMatchInvite(
      title: data['title'] ?? 'Convite para partida',
      body: data['body'] ?? 'Você foi convidado. Confirme sua presença!',
      groupId: data['groupId'] ?? '',
      matchId: data['matchId'] ?? '',
    );
    return;
  }

  // poll_reminder de evento: exibe com botões Sim/Talvez/Não
  if (data['type'] == 'poll_reminder' && data['pollType'] == 'event') {
    final optionSimId = data['optionSimId'] ?? '';
    final optionTalvezId = data['optionTalvezId'] ?? '';
    final optionNaoId = data['optionNaoId'] ?? '';
    if (optionSimId.isNotEmpty &&
        optionTalvezId.isNotEmpty &&
        optionNaoId.isNotEmpty) {
      await LocalNotifications.showEventPollReminder(
        title: data['title'] ?? 'Votação encerrando! 🗳️',
        body: data['body'] ?? 'Vote antes que seja tarde!',
        groupId: data['groupId'] ?? '',
        pollId: data['pollId'] ?? '',
        optionSimId: optionSimId,
        optionTalvezId: optionTalvezId,
        optionNaoId: optionNaoId,
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Gerencia o ciclo de vida completo das push notifications via FCM.
///
/// Uso (após login):
///   final push = PushService(tokenApi: PushTokenApi(dio), router: goRouter, navigatorKey: key);
///   await push.initialize();
class PushService {
  PushService({
    required PushTokenApi tokenApi,
    required GoRouter router,
    Future<void> Function(String groupId)? onSwitchGroup,
  })  : _tokenApi = tokenApi,
        _router = router,
        _onSwitchGroup = onSwitchGroup {
    // Callbacks de navegação para toque no corpo das notificações locais
    LocalNotifications.onMatchInviteTapped = (groupId, matchId) {
      _go(
        notificationRoute('match_invite', {
          'matchId': matchId,
          'groupId': groupId,
        }),
        groupId: groupId,
      );
    };

    LocalNotifications.onEventPollTapped = (groupId, pollId) {
      _go(
        notificationRoute('poll_reminder', {
          'pollId': pollId,
          'groupId': groupId,
          'pollType': 'event',
        }),
        groupId: groupId,
      );
    };

    LocalNotifications.onNotificationTapped = _navigate;
  }

  final PushTokenApi _tokenApi;
  final GoRouter _router;
  final Future<void> Function(String groupId)? _onSwitchGroup;
  final _log = Logger();
  late final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _initialized = false;

  // ── Inicialização ────────────────────────────────────────────────────────

  /// Chame uma vez após login bem-sucedido. Idempotente — seguro chamar múltiplas vezes.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _requestPermission();
    await _registerToken();
    _handleLocalNotificationLaunch();
    _listenTokenRefresh();
    _setupForegroundListener();
    _setupOpenedAppListener();
    await _handleInitialMessage();
  }

  // ── Permissões ───────────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    _log.d('[Push] Permissão: ${settings.authorizationStatus}');
  }

  // ── Token ────────────────────────────────────────────────────────────────

  Future<void> _registerToken() async {
    try {
      _log.i('[Push] Obtendo token FCM...');
      final token = await _fcm.getToken();
      if (token == null) {
        _log.w('[Push] Token FCM nulo — dispositivo pode não suportar push.');
        return;
      }
      _log.i('[Push] Token FCM obtido: ${token.substring(0, 20)}...');
      await _sendTokenToBackend(token);
    } catch (e, st) {
      _log.e('[Push] Erro ao obter/registrar token', error: e, stackTrace: st);
    }
  }

  /// Registra o token FCM do usuário atualmente autenticado no backend.
  ///
  /// Deve ser chamado sempre que um novo usuário fizer login, mesmo que os
  /// listeners FCM já estejam configurados (i.e., [initialize] já foi chamado).
  Future<void> registerForCurrentUser() => _registerToken();

  void _listenTokenRefresh() {
    _fcm.onTokenRefresh.listen((newToken) async {
      _log.d('[Push] Token renovado automaticamente.');
      await _sendTokenToBackend(newToken);
    });
  }

  Future<void> _sendTokenToBackend(String token) async {
    final platform = Platform.isIOS ? 'ios' : 'android';
    _log.i('[Push] Enviando token ao backend (platform=$platform)...');
    final ok = await _tokenApi.registerToken(token: token, platform: platform);
    if (ok) {
      _log.i('[Push] Token registrado no backend com sucesso.');
    } else {
      _log.e(
          '[Push] Falha ao registrar token no backend — verifique autenticação e URL da API.');
    }
  }

  /// App foi aberto pelo toque no corpo de uma notificação local (match_invite).
  Future<void> _handleLocalNotificationLaunch() async {
    final details =
        await LocalNotifications.plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return;
    final response = details.notificationResponse;
    final payload = response?.payload;
    if (payload == null || payload.isEmpty) return;

    // Quando o Android inicia o processo a partir de um botão da notificação,
    // a resposta fica em getNotificationAppLaunchDetails e não passa pelo
    // callback normal. Processa a escolha antes de navegar.
    if (response != null && LocalNotifications.isDirectAction(response)) {
      await LocalNotifications.handleAction(response);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (payload.contains('::')) {
        final parts = payload.split('::');
        final groupId = parts.isNotEmpty ? parts[0] : '';
        final entityId = parts.length >= 2 ? parts[1] : '';
        final isEventPoll = parts.length >= 5;
        _navigate({
          'type': isEventPoll ? 'poll_reminder' : 'match_invite',
          'groupId': groupId,
          if (isEventPoll) 'pollId': entityId else 'matchId': entityId,
          if (isEventPoll) 'pollType': 'event',
        });
        return;
      }

      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map) {
          _navigate(
            decoded.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
      } catch (error) {
        _log.w('[Push] Payload local inválido: $error');
      }
    });
  }

  // ── Listeners ────────────────────────────────────────────────────────────

  /// Notificações recebidas com app em FOREGROUND.
  void _setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _log.i(
          '[Push FG] ${message.notification?.title} | data: ${message.data}');
      _showForegroundNotification(message);
    });
  }

  /// Usuário tocou na notificação com app em BACKGROUND (não terminado).
  void _setupOpenedAppListener() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _log.d(
          '[Push OPEN] ${message.notification?.title} | data: ${message.data}');
      _navigate(message.data);
    });
  }

  /// App estava TERMINADO — notificação que o abriu.
  Future<void> _handleInitialMessage() async {
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      _log.d(
          '[Push INIT] ${initial.notification?.title} | data: ${initial.data}');
      // Aguarda o frame ser construído antes de navegar
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigate(initial.data);
      });
    }
  }

  // ── Navegação via payload ────────────────────────────────────────────────

  /// Interpreta o campo `type` do payload FCM e navega para a tela correta.
  /// A lógica de roteamento está centralizada em [notificationRoute].
  void _navigate(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null || type.isEmpty) {
      _log.d('[Push] Payload sem campo "type" — ignorando navegação.');
      return;
    }

    final route = notificationRoute(type, data);
    _log.d('[Push] Navegando: type=$type → $route');
    _go(route, groupId: data['groupId'] as String?);
  }

  /// Troca a patota ativa para a da notificação antes de navegar. Sem isso, a
  /// tela abria no tenant da patota atual quando o usuário tem mais de uma.
  Future<void> _go(String route, {String? groupId}) async {
    if (groupId != null && groupId.isNotEmpty && _onSwitchGroup != null) {
      try {
        await _onSwitchGroup(groupId);
      } catch (e) {
        _log.w('[Push] Falha ao trocar patota antes de navegar: $e');
      }
    }
    _router.push(route);
  }

  // ── Notificação em foreground ────────────────────────────────────────────

  void _showForegroundNotification(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;

    // match_invite é data-only — exibe com botões SIM/NÃO
    if (type == 'match_invite') {
      LocalNotifications.showMatchInvite(
        title: data['title'] ?? 'Convite para partida',
        body: data['body'] ?? 'Você foi convidado. Confirme sua presença!',
        groupId: data['groupId'] ?? '',
        matchId: data['matchId'] ?? '',
      );
      return;
    }

    // poll_reminder de evento — exibe com botões Sim/Talvez/Não
    if (type == 'poll_reminder' && data['pollType'] == 'event') {
      final optionSimId = data['optionSimId'] ?? '';
      final optionTalvezId = data['optionTalvezId'] ?? '';
      final optionNaoId = data['optionNaoId'] ?? '';
      if (optionSimId.isNotEmpty &&
          optionTalvezId.isNotEmpty &&
          optionNaoId.isNotEmpty) {
        LocalNotifications.showEventPollReminder(
          title: data['title'] ?? 'Votação encerrando! 🗳️',
          body: data['body'] ?? 'Vote antes que seja tarde!',
          groupId: data['groupId'] ?? '',
          pollId: data['pollId'] ?? '',
          optionSimId: optionSimId,
          optionTalvezId: optionTalvezId,
          optionNaoId: optionNaoId,
        );
        return;
      }
    }

    final title = message.notification?.title ?? data['title'] as String? ?? '';
    final body = message.notification?.body ?? data['body'] as String? ?? '';
    if (title.isEmpty && body.isEmpty) return;

    LocalNotifications.show(title: title, body: body, data: data);
  }
}

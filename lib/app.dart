import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/push/push_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/auth/presentation/providers/session_provider.dart';
import 'features/auth/presentation/providers/account_store.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  /// true após os listeners FCM (foreground, background, tokenRefresh) serem
  /// configurados. Diferente do registro de token, que deve ocorrer a cada
  /// novo usuário que faz login.
  bool _listenersInitialized = false;

  @override
  void initState() {
    super.initState();
    // Inicializa push se o usuário já estiver logado ao abrir o app
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryInitPush());
  }

  void _tryInitPush() {
    // Só registra push quando o perfil terminou de carregar: o registro é uma
    // chamada autenticada, e dispará-la antes do GET /me a faria sair sem a
    // identidade interna resolvida.
    if (!ref.read(sessionProvider).isReady) return;
    _schedulePushInit();
  }

  /// Decide entre inicialização completa (primeira vez) ou apenas
  /// re-registro de token (usuário trocou ou voltou após logout).
  void _schedulePushInit() {
    // Delay para deixar o frame/navegação terminar antes das chamadas de
    // plataforma do FCM, evitando congelamento visível no Android.
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      final push = ref.read(pushServiceProvider);
      if (!_listenersInitialized) {
        _listenersInitialized = true;
        push.initialize(); // listeners FCM + registro de token
      } else {
        push.registerForCurrentUser(); // só re-registra o token para o novo usuário
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Inicializa push na transição para sessão pronta — no login e também no
    // cold start, que não passa pela tela de login.
    ref.listen<SessionState>(sessionProvider, (previous, next) {
      if (!(previous?.isReady ?? false) && next.isReady) {
        _schedulePushInit();
      }
    });

    return MaterialApp.router(
      title: 'PatotasApp',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

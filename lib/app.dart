import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/push/push_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
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
    final isLoggedIn = ref.read(accountStoreProvider).isLoggedIn;
    if (!isLoggedIn) return;
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

    // Escuta mudanças de login para inicializar push assim que o usuário fizer login
    ref.listen<AccountState>(accountStoreProvider, (previous, next) {
      final wasLoggedIn = previous?.isLoggedIn ?? false;
      if (!wasLoggedIn && next.isLoggedIn) {
        _schedulePushInit();
      }
    });

    return MaterialApp.router(
      title: 'BratnavaFC',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

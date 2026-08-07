import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../router/app_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import 'push_service.dart';
import 'push_token_api.dart';

/// PushService pronto para uso, injetado com Dio autenticado e GoRouter.
final pushServiceProvider = Provider<PushService>((ref) {
  final dio = ref.watch(dioProvider);
  final router = ref.watch(routerProvider);
  return PushService(
    tokenApi: PushTokenApi(dio),
    router: router,
  );
});

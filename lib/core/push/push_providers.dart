import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../router/app_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/providers/account_store.dart';
import 'push_service.dart';
import 'push_token_api.dart';

String _normGroupId(String? id) =>
    (id ?? '').trim().toLowerCase().replaceAll(RegExp(r'[{}]'), '');

/// PushService pronto para uso, injetado com Dio autenticado e GoRouter.
final pushServiceProvider = Provider<PushService>((ref) {
  final dio = ref.watch(dioProvider);
  final router = ref.watch(routerProvider);
  return PushService(
    tokenApi: PushTokenApi(dio),
    router: router,
    // Ao tocar numa notificação de outra patota, troca o contexto ativo antes
    // de abrir a tela — senão ela carrega no tenant da patota atual.
    onSwitchGroup: (groupId) async {
      final current =
          ref.read(accountStoreProvider).activeAccount?.activeGroupId;
      if (_normGroupId(current) == _normGroupId(groupId)) return;
      await ref
          .read(authNotifierProvider.notifier)
          .selectActiveGroup(groupId: groupId);
    },
  );
});

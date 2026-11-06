import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../auth/presentation/providers/account_store.dart';
import 'billing_providers.dart';

const patotaVencidaCode = 'PATOTA_VENCIDA';

/// A API recusa escrita em patota vencida (depois da tolerância, com o bloqueio
/// ligado) com 402 e `code: PATOTA_VENCIDA`.
bool isPatotaVencida(Response<dynamic>? response) {
  if (response?.statusCode != 402) return false;
  final data = response?.data;
  if (data is! Map) return false;
  final errors = data['errors'];
  return data['code'] == patotaVencidaCode ||
      (errors is List && errors.contains(patotaVencidaCode));
}

/// Avisa quem tentou mexer numa patota vencida. Não engole o erro: a tela que
/// chamou continua recebendo a falha normalmente.
class PatotaVencidaInterceptor extends Interceptor {
  final void Function(String? groupId) onBlocked;
  PatotaVencidaInterceptor(this.onBlocked);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (isPatotaVencida(err.response)) {
      final data = err.response!.data as Map;
      onBlocked(data['groupId']?.toString());
    }
    handler.next(err);
  }
}

bool _showing = false;

/// Tela de "patota vencida". Admin e financeiro vão direto para o pagamento; o
/// jogador comum só fica sabendo que a patota está em modo somente leitura.
void showPatotaVencida(Ref ref, String? groupId) {
  if (_showing) return;
  final context = ref.read(navigatorKeyProvider).currentContext;
  if (context == null) return;

  final account = ref.read(accountStoreProvider).activeAccount;
  final gid = groupId ?? account?.activeGroupId;
  final canPay = canSeeBilling(account, gid);
  if (gid != null && canPay) ref.invalidate(groupBillingProvider(gid));

  _showing = true;
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.lock_clock_outlined),
      title: const Text('Patota em modo somente leitura'),
      content: Text(canPay
          ? 'O plano desta patota venceu. Dá para ver tudo, mas criar e alterar só volta depois do pagamento.'
          : 'O plano desta patota venceu. Dá para ver tudo, mas criar e alterar só volta quando um administrador ou financeiro pagar.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
        if (canPay && gid != null)
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(routerProvider).push('/app/plano?groupId=$gid');
            },
            child: const Text('Pagar agora'),
          ),
      ],
    ),
  ).whenComplete(() => _showing = false);
}

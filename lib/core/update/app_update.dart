import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';

/// Situação da versão instalada em relação ao `GET /api/app/version`.
enum AppUpdateStatus { upToDate, optional, required }

class AppUpdateInfo {
  final AppUpdateStatus status;
  final String? storeUrl;
  const AppUpdateInfo(this.status, [this.storeUrl]);

  static const upToDate = AppUpdateInfo(AppUpdateStatus.upToDate);
}

/// Compara o build instalado com a mínima e a mais recente da plataforma.
@visibleForTesting
AppUpdateInfo evaluateAppUpdate(
    int installedBuild, Map<String, dynamic> platform) {
  int read(String key) => (platform[key] as num?)?.toInt() ?? 0;
  final storeUrl = platform['storeUrl'] as String?;
  if (installedBuild < read('minBuild')) {
    return AppUpdateInfo(AppUpdateStatus.required, storeUrl);
  }
  if (installedBuild < read('latestBuild')) {
    return AppUpdateInfo(AppUpdateStatus.optional, storeUrl);
  }
  return AppUpdateInfo.upToDate;
}

/// Consulta a API uma vez por abertura do app. Qualquer falha (sem internet,
/// API fora, rota inexistente) conta como "em dia": nunca trava o app por erro.
final appUpdateProvider = FutureProvider<AppUpdateInfo>((ref) async {
  if (!Platform.isAndroid && !Platform.isIOS) return AppUpdateInfo.upToDate;
  try {
    final info = await PackageInfo.fromPlatform();
    final installed = int.tryParse(info.buildNumber) ?? 0;
    final dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ));
    final res = await dio.get<Map<String, dynamic>>('/api/app/version');
    final platform = res.data?[Platform.isIOS ? 'ios' : 'android'];
    if (platform is! Map<String, dynamic>) return AppUpdateInfo.upToDate;
    return evaluateAppUpdate(installed, platform);
  } catch (_) {
    return AppUpdateInfo.upToDate;
  }
});

/// Envolve o app: abaixo da versão mínima mostra uma tela que bloqueia tudo;
/// abaixo da mais recente mostra uma faixa que dá para dispensar.
class AppUpdateGate extends ConsumerStatefulWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(appUpdateProvider).valueOrNull;
    if (info == null || info.status == AppUpdateStatus.upToDate) {
      return widget.child;
    }
    if (info.status == AppUpdateStatus.required) {
      return AppUpdateRequiredScreen(storeUrl: info.storeUrl);
    }
    if (_dismissed) return widget.child;
    return Stack(children: [
      widget.child,
      Positioned(
        left: 12,
        right: 12,
        bottom: 12,
        child: SafeArea(
          child: _UpdateBanner(
            storeUrl: info.storeUrl,
            onDismiss: () => setState(() => _dismissed = true),
          ),
        ),
      ),
    ]);
  }
}

Future<void> _openStore(String? url) async {
  if (url == null || url.isEmpty) return;
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

class AppUpdateRequiredScreen extends StatelessWidget {
  const AppUpdateRequiredScreen({super.key, this.storeUrl});

  final String? storeUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.system_update_rounded,
                  size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 20),
              Text('Atualize o PatotasApp',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(
                'Esta versão não funciona mais. Atualize o app na loja para continuar usando.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              if (storeUrl != null)
                FilledButton.icon(
                  onPressed: () => _openStore(storeUrl),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Atualizar agora'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({required this.storeUrl, required this.onDismiss});

  final String? storeUrl;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
        child: Row(children: [
          const Icon(Icons.system_update_rounded, size: 20),
          const SizedBox(width: 10),
          const Expanded(child: Text('Tem uma versão nova do PatotasApp.')),
          if (storeUrl != null)
            TextButton(
                onPressed: () => _openStore(storeUrl),
                child: const Text('Atualizar')),
          IconButton(
            tooltip: 'Fechar',
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ]),
      ),
    );
  }
}

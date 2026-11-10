import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_constants.dart';
import '../api/interceptors/auth_interceptor.dart';
import '../theme/app_colors.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

Future<void> showPushDiagnosticsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const PushDiagnosticsSheet(),
  );
}

class PushDiagnosticsSheet extends ConsumerStatefulWidget {
  const PushDiagnosticsSheet({super.key});

  @override
  ConsumerState<PushDiagnosticsSheet> createState() =>
      _PushDiagnosticsSheetState();
}

class _PushDiagnosticsSheetState extends ConsumerState<PushDiagnosticsSheet> {
  bool _loading = true;
  String _permission = '...';
  String _apnsToken = '...';
  String _fcmToken = '...';
  String _backendResult = '...';
  String? _fcmTokenFull;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _permission = '...';
      _apnsToken = '...';
      _fcmToken = '...';
      _backendResult = '...';
      _fcmTokenFull = null;
    });

    // 1. Permissão
    String permission;
    try {
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      final status = s.authorizationStatus;
      permission = status == AuthorizationStatus.authorized
          ? '✅ Autorizado'
          : status == AuthorizationStatus.denied
              ? '❌ Negado'
              : status == AuthorizationStatus.provisional
                  ? '⚠️ Provisional'
                  : '⚠️ ${status.name}';
    } catch (e) {
      permission = '❌ $e';
    }
    if (!mounted) return;
    setState(() => _permission = permission);

    // 2. APNs token (iOS)
    String apnsToken;
    if (Platform.isIOS) {
      try {
        final t = await FirebaseMessaging.instance.getAPNSToken();
        apnsToken = t != null
            ? '✅ ${t.length > 20 ? '${t.substring(0, 20)}…' : t}'
            : '❌ null — timeout ou permissão negada';
      } catch (e) {
        apnsToken = '❌ $e';
      }
    } else {
      apnsToken = 'N/A (Android)';
    }
    if (!mounted) return;
    setState(() => _apnsToken = apnsToken);

    // 3. FCM token
    String fcmToken;
    String? fcmFull;
    try {
      final t = await FirebaseMessaging.instance.getToken();
      fcmFull = t;
      fcmToken = t != null
          ? '✅ ${t.length > 20 ? '${t.substring(0, 20)}…' : t}'
          : '❌ null';
    } catch (e) {
      fcmToken = '❌ $e';
    }
    if (!mounted) return;
    setState(() {
      _fcmToken = fcmToken;
      _fcmTokenFull = fcmFull;
    });

    // 4. Backend
    String backendResult;
    if (fcmFull != null) {
      try {
        final dio = ref.read(dioProvider);
        final platform = Platform.isIOS ? 'ios' : 'android';
        final response = await dio.post(
          ApiConstants.pushRegisterToken,
          data: {'token': fcmFull, 'platform': platform},
          options:
              Options(extra: {AuthInterceptor.skipUnauthorizedKey: true}),
        );
        backendResult =
            '✅ HTTP ${response.statusCode} — token salvo no backend';
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        if (code != null) {
          backendResult =
              '❌ HTTP $code${code == 401 ? ' — não autenticado (token Firebase expirado?)' : ''}';
        } else {
          backendResult = '❌ sem resposta — ${e.message}';
        }
      } catch (e) {
        backendResult = '❌ $e';
      }
    } else {
      backendResult = '⏭️ pulado — FCM token é null';
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _backendResult = backendResult;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.slate900 : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.slate400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Icon(Icons.notifications_active_outlined,
                  size: 20,
                  color: isDark ? AppColors.onDark : AppColors.slate700),
              const SizedBox(width: 8),
              Text(
                'Diagnóstico Push',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.onDark : AppColors.slate900,
                ),
              ),
              const Spacer(),
              if (_loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: 'Verificar novamente',
                  onPressed: _run,
                ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(
              color: isDark ? AppColors.slate800 : AppColors.slate100,
              height: 1),
          const SizedBox(height: 12),

          _DiagRow(
            label: 'Plataforma',
            value: Platform.isIOS ? '🍎 iOS' : '🤖 Android',
            isDark: isDark,
          ),
          _DiagRow(label: 'Permissão', value: _permission, isDark: isDark),
          _DiagRow(label: 'APNs Token', value: _apnsToken, isDark: isDark),
          _DiagRow(
            label: 'FCM Token',
            value: _fcmToken,
            isDark: isDark,
            copyValue: _fcmTokenFull,
          ),
          _DiagRow(label: 'Backend', value: _backendResult, isDark: isDark),

          const SizedBox(height: 16),
          Text(
            'Toque no FCM Token para copiar. Tire um print desta tela e mande para o time.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.slate500 : AppColors.slate400,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final String? copyValue;

  const _DiagRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.copyValue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.slate400 : AppColors.slate500,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: copyValue != null
                  ? () {
                      Clipboard.setData(ClipboardData(text: copyValue!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Token copiado!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  : null,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  color: copyValue != null
                      ? (isDark ? AppColors.info : AppColors.infoLight)
                      : (isDark ? AppColors.onDark : AppColors.slate800),
                  decoration: copyValue != null
                      ? TextDecoration.underline
                      : TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

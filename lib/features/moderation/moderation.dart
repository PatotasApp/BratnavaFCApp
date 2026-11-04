import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../auth/presentation/providers/auth_provider.dart';

/// Denunciar conteúdo e bloquear usuários (App Store, regra 1.2).
/// API: `POST /api/reports`, `POST|DELETE /api/users/{id}/block`, `GET /api/users/me/blocks`.

/// O que está sendo denunciado (espelha `ContentReportTargetType` da API).
enum ReportTarget {
  user(1, 'perfil'),
  replay(2, 'vídeo'),
  poll(3, 'enquete'),
  group(4, 'patota');

  const ReportTarget(this.apiValue, this.label);
  final int apiValue;
  final String label;
}

const reportReasons = <String>[
  'Conteúdo ofensivo ou discurso de ódio',
  'Assédio ou ameaça',
  'Nudez ou conteúdo sexual',
  'Violência',
  'Spam ou golpe',
  'Perfil falso ou se passando por outra pessoa',
  'Outro motivo',
];

class BlockedUser {
  final String userId;
  final String name;
  const BlockedUser(this.userId, this.name);
}

class ModerationDataSource {
  ModerationDataSource(this._dio);
  final Dio _dio;

  Future<void> report({
    required ReportTarget target,
    required String targetId,
    String? groupId,
    required String reason,
    String? details,
  }) async {
    await _dio.post('/api/reports', data: {
      'targetType': target.apiValue,
      'targetId': targetId,
      if (groupId != null && groupId.isNotEmpty) 'groupId': groupId,
      'reason': reason,
      if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
    });
  }

  Future<void> block(String userId) => _dio.post('/api/users/$userId/block');

  Future<void> unblock(String userId) => _dio.delete('/api/users/$userId/block');

  Future<List<BlockedUser>> blocked() async {
    final res = await _dio.get('/api/users/me/blocks');
    final body = res.data;
    final list = body is Map ? (body['data'] ?? body['Data']) : body;
    if (list is! List) return const [];
    return [
      for (final e in list.whereType<Map>())
        BlockedUser('${e['userId'] ?? e['UserId']}', '${e['name'] ?? e['Name'] ?? ''}'),
    ];
  }
}

final moderationDsProvider =
    Provider<ModerationDataSource>((ref) => ModerationDataSource(ref.watch(dioProvider)));

final blockedUsersProvider = FutureProvider.autoDispose<List<BlockedUser>>(
    (ref) => ref.watch(moderationDsProvider).blocked());

/// Abre o formulário de denúncia. Mostra o resultado num SnackBar.
Future<void> showReportSheet(
  BuildContext context, {
  required ReportTarget target,
  required String targetId,
  String? groupId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ReportSheet(target: target, targetId: targetId, groupId: groupId),
  );
}

class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({super.key, required this.target, required this.targetId, this.groupId});

  final ReportTarget target;
  final String targetId;
  final String? groupId;

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  String? _reason;
  final _details = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(moderationDsProvider).report(
            target: widget.target,
            targetId: widget.targetId,
            groupId: widget.groupId,
            reason: reason,
            details: _details.text,
          );
      navigator.pop();
      messenger.showSnackBar(const SnackBar(
          content: Text('Denúncia enviada. Vamos analisar em até 24 horas.')));
    } catch (e) {
      if (mounted) setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(extractDioError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Denunciar ${widget.target.label}', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'A denúncia é anônima para quem foi denunciado. Os administradores analisam em até 24 horas e removem o que violar os termos de uso.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) {
                if (!_sending) setState(() => _reason = v);
              },
              child: Column(children: [
                for (final r in reportReasons)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(r),
                    value: r,
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _details,
              maxLength: 1000,
              maxLines: 3,
              enabled: !_sending,
              decoration: const InputDecoration(
                labelText: 'Detalhes (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _reason == null || _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.flag_rounded),
              label: const Text('Enviar denúncia'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirma e bloqueia o usuário. Devolve true quando bloqueou.
Future<bool> confirmBlockUser(BuildContext context, WidgetRef ref,
    {required String userId, required String name}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Bloquear $name?'),
      content: const Text(
          'Vocês deixam de ver o perfil um do outro. Dá para desbloquear depois em Minha conta > Usuários bloqueados.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Bloquear')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(moderationDsProvider).block(userId);
    ref.invalidate(blockedUsersProvider);
    messenger.showSnackBar(SnackBar(content: Text('$name foi bloqueado.')));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(extractDioError(e))));
    return false;
  }
}

/// Lista dos usuários bloqueados, com desbloquear.
class BlockedUsersPage extends ConsumerWidget {
  const BlockedUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedUsersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Usuários bloqueados')),
      body: blocked.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(extractDioError(e), textAlign: TextAlign.center))),
        data: (list) => list.isEmpty
            ? const Center(child: Text('Você não bloqueou ninguém.'))
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final u = list[i];
                  return ListTile(
                    leading: const Icon(Icons.block_rounded),
                    title: Text(u.name),
                    trailing: TextButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await ref.read(moderationDsProvider).unblock(u.userId);
                          ref.invalidate(blockedUsersProvider);
                          messenger.showSnackBar(
                              SnackBar(content: Text('${u.name} foi desbloqueado.')));
                        } catch (e) {
                          messenger.showSnackBar(SnackBar(content: Text(extractDioError(e))));
                        }
                      },
                      child: const Text('Desbloquear'),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

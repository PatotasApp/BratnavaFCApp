import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/presentation/widgets/app_page_header.dart';
import '../../auth/presentation/providers/account_store.dart';
import '../group_spreadsheets.dart';
import 'spreadsheet_widgets.dart';

/// Planilhas antigas da patota: enviar e acompanhar a situação. Só admin da
/// patota (a API recusa os demais).
class GroupSpreadsheetsPage extends ConsumerWidget {
  /// Patota da notificação; sem ela, a patota ativa.
  final String? groupId;
  const GroupSpreadsheetsPage({super.key, this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountStoreProvider).activeAccount;
    final gid = (groupId != null && groupId!.isNotEmpty)
        ? groupId!
        : account?.activeGroupId;

    return Scaffold(
      body: Column(
        children: [
          const AppPageHeader(
            title: 'Planilhas antigas',
            subtitle: 'Histórico de jogos e pagamentos',
            icon: Icons.table_chart_outlined,
          ),
          Expanded(
            child: gid == null
                ? const Center(child: Text('Selecione uma patota.'))
                : _Body(groupId: gid),
          ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final String groupId;
  const _Body({required this.groupId});

  Future<void> _openUpload(BuildContext context) async {
    final kind = await showModalBottomSheet<SpreadsheetKind>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Que planilha você vai enviar?')),
            for (final k in SpreadsheetKind.values)
              ListTile(
                leading: Icon(k == SpreadsheetKind.matches
                    ? Icons.sports_soccer_outlined
                    : Icons.payments_outlined),
                title: Text(k.label),
                onTap: () => Navigator.pop(c, k),
              ),
          ],
        ),
      ),
    );
    if (kind == null || !context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
        child: SingleChildScrollView(
          child: SpreadsheetUploadForm(
            groupId: groupId,
            kinds: [kind],
            submitLabel: 'Enviar planilha',
            onSent: (_) {
              Navigator.pop(c);
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
                content: Text(
                    'Planilha enviada! Avisaremos quando a importação começar.'),
              ));
            },
          ),
        ),
      ),
    );
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, GroupSpreadsheet s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remover planilha?'),
        content: Text(
            '"${s.fileName}" será apagada e a equipe não vai mais importá-la.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Remover')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(groupSpreadsheetsDsProvider).delete(groupId, s.id);
      ref.invalidate(groupSpreadsheetsProvider(groupId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content:
              Text(extractDioError(e, 'Não foi possível remover a planilha.')),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(groupSpreadsheetsProvider(groupId));
    return RefreshIndicator(
      onRefresh: () => ref.refresh(groupSpreadsheetsProvider(groupId).future),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Se a patota controlava os jogos ou os pagamentos em planilha, envie aqui. '
            'A equipe do PatotasApp importa os dados e você recebe um aviso quando a '
            'importação começar e quando terminar.',
            style: TextStyle(fontSize: 13, color: AppColors.slate500),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('spreadsheets-new'),
            onPressed: () => _openUpload(context),
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Enviar planilha'),
          ),
          const SizedBox(height: 20),
          ...async.when(
            loading: () => [
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator()))
            ],
            error: (e, _) => [
              Text(
                  extractDioError(e, 'Não foi possível carregar as planilhas.'),
                  style: const TextStyle(color: AppColors.prototypeDanger)),
            ],
            data: (items) => items.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('Nenhuma planilha enviada ainda.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.slate500)),
                    ),
                  ]
                : [
                    for (final s in items)
                      _SpreadsheetCard(s,
                          onDelete: s.canDelete
                              ? () => _delete(context, ref, s)
                              : null),
                  ],
          ),
        ],
      ),
    );
  }
}

class _SpreadsheetCard extends StatelessWidget {
  final GroupSpreadsheet s;
  final VoidCallback? onDelete;
  const _SpreadsheetCard(this.s, {this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(s.kind.label,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? AppColors.onDark : AppColors.slate900)),
                ),
                SpreadsheetStatusChip(s.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                '${s.fileName} · ${SpreadsheetFileRules.formatSize(s.sizeBytes)}',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 2),
            Text(
              'Enviada por ${s.uploadedByName} em ${date.format(s.createdAt)}',
              style: const TextStyle(fontSize: 12, color: AppColors.slate500),
            ),
            const SizedBox(height: 6),
            Text(s.status.description,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.slate500)),
            if (s.adminNote != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate800 : AppColors.amber50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Equipe PatotasApp: ${s.adminNote}',
                    style: const TextStyle(fontSize: 13)),
              ),
            ],
            if (onDelete != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Remover'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

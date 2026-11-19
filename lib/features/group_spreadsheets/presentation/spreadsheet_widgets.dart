import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../group_spreadsheets.dart';

/// Abre o seletor do aparelho. Devolve null se a pessoa cancelar; lança
/// [FormatException] com a mensagem para mostrar quando o arquivo não serve.
Future<PickedSpreadsheet?> pickSpreadsheetFile() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: SpreadsheetFileRules.allowedExtensions,
    withData: true,
  );
  final file = result?.files.singleOrNull;
  if (file == null) return null;

  final error = SpreadsheetFileRules.validate(file.name, file.size);
  if (error != null) throw FormatException(error);
  final bytes = file.bytes;
  if (bytes == null)
    throw const FormatException(
        'Não foi possível ler o arquivo. Tente de novo.');
  return PickedSpreadsheet(file.name, bytes);
}

/// Linha "Histórico de jogos / Pagamentos" com o arquivo escolhido (ou o botão de escolher).
class SpreadsheetPickTile extends StatelessWidget {
  final SpreadsheetKind kind;
  final PickedSpreadsheet? file;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const SpreadsheetPickTile({
    super.key,
    required this.kind,
    required this.file,
    required this.onPick,
    required this.onClear,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = file;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: picked != null
              ? AppColors.emerald500
              : (isDark ? AppColors.slate700 : AppColors.slate200),
        ),
      ),
      child: Row(
        children: [
          Icon(
            kind == SpreadsheetKind.matches
                ? Icons.sports_soccer_outlined
                : Icons.payments_outlined,
            color: picked != null ? AppColors.emerald500 : AppColors.slate400,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Planilha de ${kind.label.toLowerCase()}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.onDark : AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  picked == null
                      ? 'Nenhum arquivo escolhido'
                      : '${picked.name} · ${SpreadsheetFileRules.formatSize(picked.bytes.length)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.slate400 : AppColors.slate500,
                  ),
                ),
              ],
            ),
          ),
          if (picked == null)
            TextButton.icon(
              key: Key('pick-${kind.name}'),
              onPressed: enabled ? onPick : null,
              icon: const Icon(Icons.attach_file_rounded, size: 18),
              label: const Text('Escolher'),
            )
          else
            IconButton(
              tooltip: 'Tirar arquivo',
              onPressed: enabled ? onClear : null,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
    );
  }
}

/// Selo da situação, com a cor de cada etapa.
class SpreadsheetStatusChip extends StatelessWidget {
  final SpreadsheetStatus status;
  const SpreadsheetStatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      SpreadsheetStatus.received => (AppColors.blue50, AppColors.blue600),
      SpreadsheetStatus.inProgress => (AppColors.amber50, AppColors.amber800),
      SpreadsheetStatus.finished => (AppColors.emerald50, AppColors.emerald700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// Formulário de envio: um ou dois arquivos (jogos/pagamentos) e observação.
/// Usado na pergunta logo após criar a patota e na tela de planilhas.
class SpreadsheetUploadForm extends ConsumerStatefulWidget {
  final String groupId;

  /// Tipos oferecidos. Na criação da patota, os dois; na tela, o escolhido.
  final List<SpreadsheetKind> kinds;
  final String submitLabel;
  final String? skipLabel;
  final VoidCallback? onSkip;

  /// Chamado com o que foi enviado com sucesso.
  final void Function(List<GroupSpreadsheet> sent) onSent;

  /// Seletor de arquivo; trocado nos testes.
  final Future<PickedSpreadsheet?> Function() picker;

  const SpreadsheetUploadForm({
    super.key,
    required this.groupId,
    required this.onSent,
    this.kinds = SpreadsheetKind.values,
    this.submitLabel = 'Enviar',
    this.skipLabel,
    this.onSkip,
    this.picker = pickSpreadsheetFile,
  });

  @override
  ConsumerState<SpreadsheetUploadForm> createState() =>
      _SpreadsheetUploadFormState();
}

class _SpreadsheetUploadFormState extends ConsumerState<SpreadsheetUploadForm> {
  final _files = <SpreadsheetKind, PickedSpreadsheet>{};
  final _noteCtrl = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(SpreadsheetKind kind) async {
    setState(() => _error = null);
    try {
      final file = await widget.picker();
      if (file != null && mounted) setState(() => _files[kind] = file);
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível abrir o arquivo.');
    }
  }

  Future<void> _submit() async {
    if (_files.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final ds = ref.read(groupSpreadsheetsDsProvider);
    final sent = <GroupSpreadsheet>[];
    try {
      // Um por vez, para o erro dizer qual arquivo falhou; o que já foi
      // enviado sai da lista e não é mandado de novo numa nova tentativa.
      for (final kind in widget.kinds) {
        final file = _files[kind];
        if (file == null) continue;
        final result = await ds.upload(
          groupId: widget.groupId,
          kind: kind,
          file: file,
          note: _noteCtrl.text,
        );
        if (result != null) sent.add(result);
        _files.remove(kind);
      }
      ref.invalidate(groupSpreadsheetsProvider(widget.groupId));
      if (mounted) widget.onSent(sent);
    } catch (e) {
      ref.invalidate(groupSpreadsheetsProvider(widget.groupId));
      if (mounted) {
        setState(() =>
            _error = extractDioError(e, 'Não foi possível enviar a planilha.'));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final kind in widget.kinds) ...[
          SpreadsheetPickTile(
            kind: kind,
            file: _files[kind],
            enabled: !_sending,
            onPick: () => _pick(kind),
            onClear: () => setState(() => _files.remove(kind)),
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _noteCtrl,
          enabled: !_sending,
          maxLength: 1000,
          maxLines: 2,
          minLines: 1,
          decoration: const InputDecoration(
            labelText: 'Observação (opcional)',
            hintText: 'Ex.: os jogos de 2024 estão na segunda aba',
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Formatos: .xlsx, .xls, .csv, .ods ou .pdf, até 10 MB. '
          'A equipe do PatotasApp importa os dados e avisa você.',
          style: TextStyle(fontSize: 12, color: AppColors.slate500),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!,
              style: const TextStyle(
                  color: AppColors.prototypeDanger, fontSize: 13)),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('spreadsheet-submit'),
          onPressed: _sending || _files.isEmpty ? null : _submit,
          icon: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.cloud_upload_outlined),
          label: Text(widget.submitLabel),
        ),
        if (widget.onSkip != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _sending ? null : widget.onSkip,
            child: Text(widget.skipLabel ?? 'Agora não'),
          ),
        ],
      ],
    );
  }
}

/// Pergunta feita logo depois de criar a patota. Pular é normal: dá para
/// enviar depois em Configurações > Planilhas antigas.
Future<void> showSpreadsheetOnboardingSheet(
  BuildContext context, {
  required String groupId,
  required String groupName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(sheetContext).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.table_chart_outlined,
                size: 36, color: AppColors.emerald500),
            const SizedBox(height: 10),
            Text(
              'A $groupName já tinha planilhas?',
              textAlign: TextAlign.center,
              style: Theme.of(sheetContext)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Se vocês controlavam os jogos ou os pagamentos em planilha, '
              'mande aqui. A equipe do PatotasApp importa o histórico para a patota.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.slate500),
            ),
            const SizedBox(height: 16),
            SpreadsheetUploadForm(
              groupId: groupId,
              submitLabel: 'Enviar planilhas',
              skipLabel: 'Não tenho / enviar depois',
              onSkip: () {
                Navigator.pop(sheetContext);
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
                  content: Text(
                      'Você pode enviar depois em Configurações da patota > Planilhas antigas.'),
                ));
              },
              onSent: (sent) {
                Navigator.pop(sheetContext);
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
                  content: Text(sent.length == 1
                      ? 'Planilha enviada! Avisaremos quando a importação começar.'
                      : 'Planilhas enviadas! Avisaremos quando a importação começar.'),
                ));
              },
            ),
          ],
        ),
      ),
    ),
  );
}

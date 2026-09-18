import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/polls_remote_datasource.dart';
import '../../domain/entities/poll_detail.dart';
import '../providers/polls_provider.dart';
import 'poll_form_widgets.dart';

/// Opção montada localmente enquanto a votação ainda não foi criada.
/// Nada é enviado ao backend até o usuário confirmar em "Criar Votação".
class _DraftOption {
  final String text;
  final String? description;
  final String? imageB64;
  const _DraftOption(this.text, this.description, this.imageB64);
}

class CreatePollSheet extends ConsumerStatefulWidget {
  final String groupId;
  final ValueChanged<PollDetail> onCreated;

  const CreatePollSheet(
      {super.key, required this.groupId, required this.onCreated});

  @override
  ConsumerState<CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends ConsumerState<CreatePollSheet> {
  int _step = 0; // 0 = config, 1 = options

  // Step 1 — Config
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _multipleVotes = false;
  bool _showVotes = false;
  final _deadlineDateCtrl = TextEditingController();
  final _deadlineTimeCtrl = TextEditingController();

  // Step 2 — Options (mantidas localmente até a criação final)
  final List<_DraftOption> _options = [];
  final _optTextCtrl = TextEditingController();
  final _optDescCtrl = TextEditingController();
  String? _optImageB64;
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _deadlineDateCtrl.dispose();
    _deadlineTimeCtrl.dispose();
    _optTextCtrl.dispose();
    _optDescCtrl.dispose();
    super.dispose();
  }

  PollsRemoteDataSource get _ds => ref.read(pollsDsProvider);

  // Apenas avança de etapa — não cria nada no backend ainda.
  void _goToOptions() {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Informe o título.')));
      return;
    }
    setState(() => _step = 1);
  }

  Future<void> _pickImage() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Galeria'),
            onTap: () => Navigator.pop(context, ImageSource.gallery)),
        ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Câmera'),
            onTap: () => Navigator.pop(context, ImageSource.camera)),
      ])),
    );
    if (src == null) return;
    final file = await ImagePicker().pickImage(source: src);
    if (file == null) return;
    final compressed = await FlutterImageCompress.compressWithFile(
      file.path,
      minWidth: 1280,
      minHeight: 1280,
      quality: 78,
    );
    if (compressed == null) return;
    setState(() =>
        _optImageB64 = 'data:image/jpeg;base64,${base64Encode(compressed)}');
  }

  void _addOptionLocal() {
    if (_optTextCtrl.text.trim().isEmpty) return;
    setState(() {
      _options.add(_DraftOption(
        _optTextCtrl.text.trim(),
        _optDescCtrl.text.trim().isNotEmpty ? _optDescCtrl.text.trim() : null,
        _optImageB64,
      ));
      _optTextCtrl.clear();
      _optDescCtrl.clear();
      _optImageB64 = null;
    });
  }

  void _removeOptionLocal(int index) {
    setState(() => _options.removeAt(index));
  }

  // Cria a votação UMA única vez, com todas as opções, ao confirmar.
  Future<void> _submit() async {
    if (_options.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      final poll = await _ds.createPoll(widget.groupId, {
        'title': _titleCtrl.text.trim(),
        'description':
            _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
        'allowMultipleVotes': _multipleVotes,
        'showVotes': _showVotes,
        'deadlineDate':
            _deadlineDateCtrl.text.isNotEmpty ? _deadlineDateCtrl.text : null,
        'deadlineTime':
            _deadlineTimeCtrl.text.isNotEmpty ? _deadlineTimeCtrl.text : null,
      });
      for (final opt in _options) {
        await _ds.addOption(widget.groupId, poll.id, {
          'text': opt.text,
          'description': opt.description,
          'images': opt.imageB64 != null ? [opt.imageB64] : <String>[],
        });
      }
      // Busca o poll completo (com as opções) para entregar ao caller.
      final full = await _ds.getPoll(widget.groupId, poll.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onCreated(full);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao criar: $e'),
            backgroundColor: AppColors.rose500));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : AppColors.onDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.slate300,
                    borderRadius: BorderRadius.circular(2))),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(children: [
                Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: AppColors.slate900,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.how_to_vote_outlined,
                        color: AppColors.onDark, size: 18)),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Nova Votação',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(
                          'Passo ${_step + 1} de 2: ${_step == 0 ? 'Configuração' : 'Opções'}',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.slate400
                                  : AppColors.slate500)),
                    ])),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop()),
              ]),
            ),
            // Step indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(children: [
                Expanded(
                    child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                            color: AppColors.slate900,
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(width: 4),
                Expanded(
                    child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                            color: _step == 1
                                ? AppColors.slate900
                                : AppColors.slate200,
                            borderRadius: BorderRadius.circular(2)))),
              ]),
            ),
            Expanded(
              child: _step == 0
                  ? _Step1(
                      controller: controller,
                      titleCtrl: _titleCtrl,
                      descCtrl: _descCtrl,
                      multipleVotes: _multipleVotes,
                      showVotes: _showVotes,
                      deadlineDateCtrl: _deadlineDateCtrl,
                      deadlineTimeCtrl: _deadlineTimeCtrl,
                      isDark: isDark,
                      onMultipleChanged: (v) =>
                          setState(() => _multipleVotes = v),
                      onShowVotesChanged: (v) => setState(() => _showVotes = v),
                      onNext: _goToOptions,
                    )
                  : _Step2(
                      controller: controller,
                      options: _options,
                      optTextCtrl: _optTextCtrl,
                      optDescCtrl: _optDescCtrl,
                      optImageB64: _optImageB64,
                      submitting: _submitting,
                      isDark: isDark,
                      onPickImage: _pickImage,
                      onAddOption: _addOptionLocal,
                      onRemoveOption: _removeOptionLocal,
                      onBack: () => setState(() => _step = 0),
                      onSubmit: _submit,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 1 ────────────────────────────────────────────────────────────────────

class _Step1 extends StatelessWidget {
  final ScrollController controller;
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final TextEditingController deadlineDateCtrl;
  final TextEditingController deadlineTimeCtrl;
  final bool multipleVotes;
  final bool showVotes;
  final bool isDark;
  final ValueChanged<bool> onMultipleChanged;
  final ValueChanged<bool> onShowVotesChanged;
  final VoidCallback onNext;

  const _Step1({
    required this.controller,
    required this.titleCtrl,
    required this.descCtrl,
    required this.deadlineDateCtrl,
    required this.deadlineTimeCtrl,
    required this.multipleVotes,
    required this.showVotes,
    required this.isDark,
    required this.onMultipleChanged,
    required this.onShowVotesChanged,
    required this.onNext,
  });

  Widget _label(String t, bool isDark) => Text(t,
      style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.slate300 : AppColors.slate600));

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _label('Título *', isDark),
        const SizedBox(height: 4),
        TextFormField(
            controller: titleCtrl,
            decoration: const InputDecoration(
                isDense: true, contentPadding: EdgeInsets.all(10))),
        const SizedBox(height: 10),
        _label('Descrição (opcional)', isDark),
        const SizedBox(height: 4),
        TextFormField(
            controller: descCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
                isDense: true, contentPadding: EdgeInsets.all(10))),
        const SizedBox(height: 12),
        PollSectionCard(
            isDark: isDark,
            child: Row(children: [
              Icon(Icons.check_box_outlined,
                  size: 16,
                  color: isDark ? AppColors.slate300 : AppColors.slate600),
              const SizedBox(width: 8),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Múltipla escolha',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('Membros podem escolher mais de uma opção',
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.slate400
                                : AppColors.slate500)),
                  ])),
              Switch(value: multipleVotes, onChanged: onMultipleChanged),
            ])),
        const SizedBox(height: 8),
        PollSectionCard(
            isDark: isDark,
            child: Row(children: [
              Icon(Icons.visibility_outlined,
                  size: 16,
                  color: isDark ? AppColors.slate300 : AppColors.slate600),
              const SizedBox(width: 8),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Votos visíveis',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('Todos veem quem votou em quê',
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.slate400
                                : AppColors.slate500)),
                  ])),
              Switch(value: showVotes, onChanged: onShowVotesChanged),
            ])),
        const SizedBox(height: 12),
        _label('Prazo (opcional)', isDark),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
              child: PollDateField(
                  label: 'Data', controller: deadlineDateCtrl, isDark: isDark)),
          const SizedBox(width: 10),
          Expanded(
              child: PollTimeField(
                  label: 'Hora', controller: deadlineTimeCtrl, isDark: isDark)),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onNext,
            child: const Text('Próximo — Adicionar opções'),
          ),
        ),
      ],
    );
  }
}

// ── Step 2 ────────────────────────────────────────────────────────────────────

class _Step2 extends StatelessWidget {
  final ScrollController controller;
  final List<_DraftOption> options;
  final TextEditingController optTextCtrl;
  final TextEditingController optDescCtrl;
  final String? optImageB64;
  final bool submitting;
  final bool isDark;
  final VoidCallback onPickImage;
  final VoidCallback onAddOption;
  final ValueChanged<int> onRemoveOption;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  const _Step2({
    required this.controller,
    required this.options,
    required this.optTextCtrl,
    required this.optDescCtrl,
    required this.optImageB64,
    required this.submitting,
    required this.isDark,
    required this.onPickImage,
    required this.onAddOption,
    required this.onRemoveOption,
    required this.onBack,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        // Existing options (local)
        if (options.isNotEmpty) ...[
          Text('Opções adicionadas (${options.length})',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.slate300 : AppColors.slate600)),
          const SizedBox(height: 8),
          ...options.asMap().entries.map((entry) {
            final i = entry.key;
            final opt = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate800 : AppColors.slate50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isDark ? AppColors.slate700 : AppColors.slate200),
              ),
              child: Row(children: [
                if (opt.imageB64 != null) ...[
                  ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(
                          base64Decode(opt.imageB64!.split(',').last),
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.image_outlined, size: 36))),
                  const SizedBox(width: 8),
                ],
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(opt.text,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.onDark
                                  : AppColors.slate900)),
                      if (opt.description != null)
                        Text(opt.description!,
                            style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.slate400
                                    : AppColors.slate500)),
                    ])),
                IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.close,
                        size: 16, color: AppColors.rose500),
                    onPressed: submitting ? null : () => onRemoveOption(i)),
              ]),
            );
          }),
          const Divider(height: 20),
        ],

        // Add new option
        Text('Adicionar opção',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.slate300 : AppColors.slate600)),
        const SizedBox(height: 6),
        TextFormField(
            controller: optTextCtrl,
            decoration: const InputDecoration(
                labelText: 'Texto *',
                isDense: true,
                contentPadding: EdgeInsets.all(10))),
        const SizedBox(height: 6),
        TextFormField(
            controller: optDescCtrl,
            decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
                isDense: true,
                contentPadding: EdgeInsets.all(10))),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onPickImage,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              border: Border.all(
                  color: isDark ? AppColors.slate600 : AppColors.slate300),
              borderRadius: BorderRadius.circular(10),
              color: isDark ? AppColors.slate700 : AppColors.slate50,
            ),
            child: optImageB64 != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                        base64Decode(optImageB64!.split(',').last),
                        fit: BoxFit.cover,
                        width: double.infinity))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        size: 18,
                        color:
                            isDark ? AppColors.slate400 : AppColors.slate500),
                    const SizedBox(width: 6),
                    Text('Adicionar imagem (opcional)',
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.slate400
                                : AppColors.slate500)),
                  ]),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: submitting ? null : onAddOption,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Adicionar opção'),
          ),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
              child: OutlinedButton(
                  onPressed: submitting ? null : onBack,
                  child: const Text('Voltar'))),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: (options.isEmpty || submitting) ? null : onSubmit,
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.onDark))
                  : const Text('Criar Votação'),
            ),
          ),
        ]),
        if (options.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Adicione pelo menos uma opção para criar.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.slate500 : AppColors.slate400)),
          ),
      ],
    );
  }
}

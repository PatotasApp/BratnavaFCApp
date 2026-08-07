import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../data/datasources/payments_remote_datasource.dart';
import '../../domain/entities/payment_entities.dart';
import 'payment_sheet_widgets.dart';

const kMonths = [
  'Jan',
  'Fev',
  'Mar',
  'Abr',
  'Mai',
  'Jun',
  'Jul',
  'Ago',
  'Set',
  'Out',
  'Nov',
  'Dez',
];

/// [onSubmit] recebe o dto montado (com base64 se houver) e faz a chamada API.
/// [onSaveRating] é chamado com (starRating) quando o admin altera a avaliação.
class MonthlyPaymentSheet extends StatefulWidget {
  final String groupId;
  final PlayerRow row;
  final int month;
  final bool isAdmin;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final Future<void> Function(int starRating)? onSaveRating;
  final VoidCallback onSaved;

  const MonthlyPaymentSheet({
    super.key,
    required this.groupId,
    required this.row,
    required this.month,
    required this.isAdmin,
    required this.onSubmit,
    this.onSaveRating,
    required this.onSaved,
  });

  @override
  State<MonthlyPaymentSheet> createState() => _MonthlyPaymentSheetState();
}

class _MonthlyPaymentSheetState extends State<MonthlyPaymentSheet> {
  late final TextEditingController _discCtrl;
  late final TextEditingController _reasonCtrl;
  String? _pickedPath;
  String? _pickedName;
  bool _saving = false;
  int? _starRating; // avaliação 1–5 estrelas

  MonthlyCell? get _cell =>
      widget.row.months.where((c) => c.month == widget.month).firstOrNull;

  @override
  void initState() {
    super.initState();
    _discCtrl =
        TextEditingController(text: (_cell?.discount ?? 0).toStringAsFixed(2));
    _reasonCtrl = TextEditingController(text: _cell?.discountReason ?? '');
    _starRating = widget.row.starRating;
  }

  @override
  void dispose() {
    _discCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Galeria'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Câmera'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ]),
      ),
    );
    if (src == null || !mounted) return;
    final xFile = await ImagePicker().pickImage(source: src, imageQuality: 80);
    if (xFile == null || !mounted) return;
    final compressed = await FlutterImageCompress.compressWithFile(
      xFile.path,
      minWidth: 1280,
      minHeight: 1280,
      quality: 78,
    );
    if (compressed == null || !mounted) return;
    setState(() {
      _pickedPath = xFile.path;
      _pickedName = xFile.name;
    });
  }

  Future<void> _submit(int status) async {
    setState(() => _saving = true);
    try {
      final dto = <String, dynamic>{
        'playerId': widget.row.playerId,
        'year': DateTime.now().year,
        'month': widget.month,
        'status': status,
      };

      if (widget.isAdmin) {
        dto['discount'] = double.tryParse(_discCtrl.text) ?? 0.0;
        final reason = _reasonCtrl.text.trim();
        if (reason.isNotEmpty) dto['discountReason'] = reason;
      }

      if (_pickedPath != null && _pickedName != null) {
        final proof = await PaymentsRemoteDataSource.fileToBase64(
            _pickedPath!, _pickedName!);
        dto['proofBase64'] = proof.base64;
        dto['proofFileName'] = proof.fileName;
        dto['proofMimeType'] = proof.mimeType;
      }

      await widget.onSubmit(dto);

      // Save rating if admin changed it
      if (widget.isAdmin &&
          widget.onSaveRating != null &&
          _starRating != null &&
          _starRating != widget.row.starRating) {
        try {
          await widget.onSaveRating!(_starRating!);
        } catch (_) {
          // Rating save failure is non-critical — don't block the payment save
        }
      }

      if (mounted) {
        widget.onSaved();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: AppColors.rose500,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cell = _cell;
    final isPaid = cell?.isPaid ?? false;

    return SheetContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHandle(isDark: isDark),
          const SizedBox(height: 16),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              ConfiguredPlayerName(
                groupId: widget.groupId,
                name: widget.row.playerName,
                isGoalkeeper: widget.row.isGoalkeeper,
                iconSize: 17,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.onDark : AppColors.slate900,
                ),
              ),
              Text(
                '— ${kMonths[widget.month - 1]}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.onDark : AppColors.slate900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Valor: R\$ ${(cell?.amount ?? 0).toStringAsFixed(2)}'
            '${(cell?.discount ?? 0) > 0 ? ' · Desconto: R\$ ${cell!.discount.toStringAsFixed(2)}' : ''}',
            style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.slate400 : AppColors.slate500),
          ),
          const SizedBox(height: 20),
          if (widget.isAdmin) ...[
            FieldLabel('Desconto (R\$)', isDark),
            const SizedBox(height: 6),
            SheetField(
              controller: _discCtrl,
              isDark: isDark,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
              ],
            ),
            const SizedBox(height: 12),
            FieldLabel('Motivo do desconto', isDark),
            const SizedBox(height: 6),
            SheetField(
                controller: _reasonCtrl, isDark: isDark, hint: 'Opcional'),
            const SizedBox(height: 20),

            // ── Avaliação do jogador ───────────────────────────────────
            _RatingSectionDivider(isDark: isDark),
            const SizedBox(height: 12),
            FieldLabel('Avaliação do jogador', isDark),
            const SizedBox(height: 4),
            Text(
              'Nível estimado (1–5 estrelas)',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.slate500 : AppColors.slate400,
              ),
            ),
            const SizedBox(height: 8),
            _StarPicker(
              value: _starRating,
              disabled: _saving,
              onChanged: (v) => setState(() => _starRating = v),
            ),
            const SizedBox(height: 12),
          ],
          FieldLabel('Comprovante (opcional)', isDark),
          const SizedBox(height: 6),
          ProofPicker(
            isDark: isDark,
            pickedName: _pickedName,
            existingProof: cell?.hasProof == true ? cell?.proofFileName : null,
            onPick: _pickImage,
            onClear: () => setState(() {
              _pickedPath = null;
              _pickedName = null;
            }),
          ),
          const SizedBox(height: 24),
          Row(children: [
            if (!isPaid)
              Expanded(
                child: ActionBtn(
                  label: 'Marcar como pago',
                  icon: Icons.check_circle_outline,
                  color: AppColors.primaryPressed,
                  loading: _saving,
                  onTap: () => _submit(1),
                ),
              ),
            if (isPaid && widget.isAdmin)
              Expanded(
                child: ActionBtn(
                  label: 'Marcar pendente',
                  icon: Icons.cancel_outlined,
                  color: AppColors.rose500,
                  loading: _saving,
                  onTap: () => _submit(0),
                ),
              ),
            if (!isPaid && widget.isAdmin) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlineBtn(
                  label: 'Só desconto',
                  isDark: isDark,
                  onTap: _saving ? null : () => _submit(0),
                ),
              ),
            ],
            const SizedBox(width: 8),
            OutlineBtn(
              label: 'Cancelar',
              isDark: isDark,
              padH: 16,
              onTap: () => Navigator.of(context).pop(),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Rating section divider ────────────────────────────────────────────────────

class _RatingSectionDivider extends StatelessWidget {
  final bool isDark;
  const _RatingSectionDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: isDark ? AppColors.slate700 : AppColors.slate200,
            height: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star_rounded,
                size: 12,
                color: isDark ? AppColors.slate500 : AppColors.slate400,
              ),
              const SizedBox(width: 4),
              Text(
                'Avaliação',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: isDark ? AppColors.slate500 : AppColors.slate400,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Divider(
            color: isDark ? AppColors.slate700 : AppColors.slate200,
            height: 1,
          ),
        ),
      ],
    );
  }
}

// ── Star picker ───────────────────────────────────────────────────────────────

class _StarPicker extends StatelessWidget {
  final int? value;
  final bool disabled;
  final ValueChanged<int> onChanged;

  const _StarPicker({
    required this.value,
    required this.disabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final star = i + 1;
        final filled = value != null && star <= value!;
        return GestureDetector(
          onTap: disabled ? null : () => onChanged(star),
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Icon(
                filled ? Icons.star_rounded : Icons.star_border_rounded,
                key: ValueKey('$star-$filled'),
                size: 32,
                color: filled ? AppColors.warning : AppColors.lightTextMuted,
              ),
            ),
          ),
        );
      }),
    );
  }
}

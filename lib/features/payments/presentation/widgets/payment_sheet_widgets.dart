import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';

// ── Container base do bottom sheet ───────────────────────────────────────────

class SheetContainer extends StatelessWidget {
  final bool isDark;
  final Widget child;
  const SheetContainer({super.key, required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate800 : AppColors.onDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(child: child),
      );
}

// ── Handle (draggable indicator) ──────────────────────────────────────────────

class SheetHandle extends StatelessWidget {
  final bool isDark;
  const SheetHandle({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate600 : AppColors.slate200,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

// ── Label de campo ────────────────────────────────────────────────────────────

class FieldLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const FieldLabel(this.text, this.isDark, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.slate300 : AppColors.slate600,
        ),
      );
}

// ── Campo de texto padrão ─────────────────────────────────────────────────────

class SheetField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;

  const SheetField({
    super.key,
    required this.controller,
    required this.isDark,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.onDark : AppColors.slate900),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              color: isDark ? AppColors.slate500 : AppColors.slate400),
          filled: true,
          fillColor: isDark ? AppColors.slate700 : AppColors.slate50,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
                color: isDark ? AppColors.slate600 : AppColors.slate200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
                color: isDark ? AppColors.slate600 : AppColors.slate200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
                color: isDark ? AppColors.onDark : AppColors.slate900,
                width: 1.5),
          ),
        ),
      );
}

// ── Seletor de comprovante ────────────────────────────────────────────────────

class ProofPicker extends StatelessWidget {
  final bool isDark;
  final String? pickedName;
  final String? existingProof;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const ProofPicker({
    super.key,
    required this.isDark,
    this.pickedName,
    this.existingProof,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.slate400 : AppColors.slate500;
    return GestureDetector(
      onTap: pickedName == null ? onPick : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate700 : AppColors.slate50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isDark ? AppColors.slate600 : AppColors.slate200),
        ),
        child: Row(children: [
          Icon(Icons.attach_file_rounded, size: 16, color: sub),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pickedName ??
                  (existingProof != null
                      ? 'Já enviado: $existingProof'
                      : 'Selecionar imagem'),
              style: TextStyle(fontSize: 13, color: sub),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (pickedName != null)
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close, size: 16, color: sub),
            )
          else
            GestureDetector(
              onTap: onPick,
              child: Icon(Icons.photo_camera_outlined, size: 16, color: sub),
            ),
        ]),
      ),
    );
  }
}

// ── Botão de ação principal ───────────────────────────────────────────────────

class ActionBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final Color foregroundColor;
  final bool loading;
  final VoidCallback? onTap;

  const ActionBtn({
    super.key,
    required this.label,
    this.icon,
    required this.color,
    this.foregroundColor = AppColors.onDark,
    required this.loading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
        onPressed: loading ? null : onTap,
        icon: loading
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 1.8, color: foregroundColor),
              )
            : Icon(icon, size: 15),
        label: Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
      );
}

// ── Botão outline ─────────────────────────────────────────────────────────────

class OutlineBtn extends StatelessWidget {
  final String label;
  final bool isDark;
  final VoidCallback? onTap;
  final double padH;

  const OutlineBtn({
    super.key,
    required this.label,
    required this.isDark,
    this.onTap,
    this.padH = 0,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
              color: isDark ? AppColors.slate600 : AppColors.slate200),
          foregroundColor: isDark ? AppColors.slate200 : AppColors.slate700,
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      );
}

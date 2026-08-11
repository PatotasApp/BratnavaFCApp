import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../members/presentation/providers/members_provider.dart';

/// Avatar do usuário com edição de foto (tirar/escolher/excluir).
/// Reutilizado na aba "Perfil" e na página de perfil (quando é o próprio dono).
class EditableProfileAvatar extends ConsumerStatefulWidget {
  final String userId;
  final String name;
  final String? photoUrl;
  final double size;
  final double avatarBorderRadius;

  const EditableProfileAvatar({
    super.key,
    required this.userId,
    required this.name,
    required this.photoUrl,
    this.size = 64,
    this.avatarBorderRadius = 18,
  });

  @override
  ConsumerState<EditableProfileAvatar> createState() =>
      _EditableProfileAvatarState();
}

class _EditableProfileAvatarState extends ConsumerState<EditableProfileAvatar> {
  bool _busy = false;

  Future<void> _chooseSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Foto do perfil',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Tirar foto'),
                subtitle: const Text('Usar a câmera do aparelho'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Escolher da galeria'),
                subtitle: const Text('Carregar uma foto existente'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source != null) await _pick(source);
  }

  Future<void> _pick(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 92,
    );
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final compressed = await FlutterImageCompress.compressWithFile(
        picked.path,
        minWidth: 720,
        minHeight: 720,
        quality: 82,
        format: CompressFormat.jpeg,
      );
      if (compressed == null) {
        throw Exception('Não foi possível processar a foto.');
      }
      if (compressed.length > 5 * 1024 * 1024) {
        throw Exception('A foto deve ter no máximo 5 MB.');
      }

      await ref
          .read(membersDsProvider)
          .uploadProfilePhoto(widget.userId, compressed);
      _refreshPhoto();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto atualizada com sucesso.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir foto?'),
        content:
            const Text('As iniciais voltarão a ser exibidas no seu perfil.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(membersDsProvider).deleteProfilePhoto(widget.userId);
      _refreshPhoto();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto removida.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refreshPhoto() {
    ref.invalidate(myProfileProvider);
    ref.invalidate(myPlayersProvider);
    ref.invalidate(usersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AvatarWidget(
              name: widget.name,
              photoUrl: widget.photoUrl,
              size: widget.size,
              borderRadius: widget.avatarBorderRadius,
            ),
            Positioned(
              right: -5,
              bottom: -5,
              child: Material(
                color: colors.primary,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: _busy ? null : _chooseSource,
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: _busy
                        ? Padding(
                            padding: const EdgeInsets.all(7),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onPrimary,
                            ),
                          )
                        : Icon(Icons.camera_alt_rounded,
                            size: 15, color: colors.onPrimary),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (widget.photoUrl != null) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: _busy ? null : _remove,
            child: Text('Excluir',
                style: TextStyle(
                    color: colors.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }
}

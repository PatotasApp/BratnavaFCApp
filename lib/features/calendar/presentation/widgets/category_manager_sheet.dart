import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/calendar_remote_datasource.dart';
import '../../domain/entities/calendar_event.dart';

class CategoryManagerSheet extends StatefulWidget {
  final String groupId;
  final CalendarRemoteDataSource datasource;
  final List<CalendarCategory> categories;
  final VoidCallback onChanged;

  const CategoryManagerSheet({
    super.key,
    required this.groupId,
    required this.datasource,
    required this.categories,
    required this.onChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required String groupId,
    required CalendarRemoteDataSource datasource,
    required List<CalendarCategory> categories,
    required VoidCallback onChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => CategoryManagerSheet(
        groupId: groupId,
        datasource: datasource,
        categories: categories,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<CategoryManagerSheet> createState() => _CategoryManagerSheetState();
}

class _CategoryManagerSheetState extends State<CategoryManagerSheet> {
  late List<CalendarCategory> _cats;
  bool _adding = false;
  final _nameCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cats = widget.categories.where((c) => !c.isSystem).toList();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _delete(CalendarCategory cat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir categoria'),
        content: Text(
            'Excluir "${cat.name}"? Os eventos desta categoria não serão excluídos.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir',
                  style: TextStyle(color: AppColors.prototypeDanger))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.datasource.deleteCategory(widget.groupId, cat.id);
      setState(() => _cats.removeWhere((c) => c.id == cat.id));
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  Future<void> _add() async {
    final name = _nameCtrl.text.trim();
    final color = _colorCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _adding = true);
    try {
      await widget.datasource.createCategory(widget.groupId, {
        'name': name,
        if (color.isNotEmpty)
          'color': color.startsWith('#') ? color : '#$color',
      });
      _nameCtrl.clear();
      _colorCtrl.clear();
      widget.onChanged();
      // Reload categories
      final updated = await widget.datasource.fetchCategories(widget.groupId);
      if (mounted) {
        setState(() {
          _cats = updated.where((c) => !c.isSystem).toList();
          _adding = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
        setState(() => _adding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : AppColors.onDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle + Header
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate700 : AppColors.slate200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Gerenciar categorias',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.onDark : AppColors.slate900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                    color: isDark ? AppColors.slate500 : AppColors.slate400,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Formulário de nova categoria
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  // Nome
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _nameCtrl,
                      style: TextStyle(
                          fontSize: 13,
                          color:
                              isDark ? AppColors.slate200 : AppColors.slate800),
                      decoration: _inputDecor('Nome', isDark),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Cor
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _colorCtrl,
                      style: TextStyle(
                          fontSize: 13,
                          color:
                              isDark ? AppColors.slate200 : AppColors.slate800),
                      decoration: _inputDecor('#hex', isDark),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botão adicionar
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: FilledButton(
                      onPressed: _adding ? null : _add,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            isDark ? AppColors.onDark : AppColors.slate900,
                        foregroundColor:
                            isDark ? AppColors.slate900 : AppColors.onDark,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.zero,
                      ),
                      child: _adding
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.onDark))
                          : const Icon(Icons.add, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Lista de categorias
            Expanded(
              child: _cats.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhuma categoria personalizada.',
                        style: TextStyle(
                          color:
                              isDark ? AppColors.slate500 : AppColors.slate400,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _cats.length,
                      separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color:
                              isDark ? AppColors.slate800 : AppColors.slate100),
                      itemBuilder: (_, i) {
                        final cat = _cats[i];
                        Color? dotColor;
                        try {
                          if (cat.color != null) {
                            dotColor = Color(int.parse(
                                '0xFF${cat.color!.replaceAll('#', '')}'));
                          }
                        } catch (_) {}

                        return ListTile(
                          leading: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: dotColor ?? AppColors.slate200,
                            ),
                          ),
                          title: Text(
                            cat.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.onDark
                                  : AppColors.slate800,
                            ),
                          ),
                          subtitle: cat.color != null
                              ? Text(cat.color!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.slate500
                                        : AppColors.slate400,
                                  ))
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 20),
                            color: AppColors.rose500,
                            onPressed: () => _delete(cat),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecor(String hint, bool isDark) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: isDark ? AppColors.slate600 : AppColors.slate400,
            fontSize: 13),
        filled: true,
        fillColor: isDark ? AppColors.slate800 : AppColors.slate50,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
                color: isDark ? AppColors.slate700 : AppColors.slate200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
                color: isDark ? AppColors.slate700 : AppColors.slate200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
                color: isDark ? AppColors.slate400 : AppColors.slate500,
                width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      );
}

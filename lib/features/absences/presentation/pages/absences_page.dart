import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/confirm_dialog.dart';
import '../../data/datasources/absences_remote_datasource.dart';
import '../../domain/entities/absence.dart';
import '../providers/absences_provider.dart';
import '../widgets/absence_form_sheet.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _formatDate(String d) {
  final parts = d.split('-');
  if (parts.length != 3) return d;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

IconData _absenceIcon(int type) {
  switch (type) {
    case 1:
      return Icons.flight_outlined;
    case 2:
      return Icons.local_hospital_outlined;
    case 3:
      return Icons.favorite_border;
    default:
      return Icons.more_horiz_outlined;
  }
}

// ── Page ──────────────────────────────────────────────────────────────────────

class AbsencesPage extends ConsumerStatefulWidget {
  const AbsencesPage({super.key});

  @override
  ConsumerState<AbsencesPage> createState() => _AbsencesPageState();
}

class _AbsencesPageState extends ConsumerState<AbsencesPage> {
  static const _pageSizeOptions = [5, 10, 20, 50];
  int _page = 1;
  int _pageSize = 5;

  AbsencesRemoteDataSource get _ds => ref.read(absencesDsProvider);

  void _refresh() {
    setState(() => _page = 1);
    ref.invalidate(absencesProvider);
  }

  Future<void> _openCreate() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AbsenceFormSheet(
        onSave: (dto) async {
          await _ds.create(dto);
          if (mounted) Navigator.of(context).pop();
          _refresh();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ausência cadastrada.')));
          }
        },
      ),
    );
  }

  Future<void> _openEdit(AbsenceDto absence) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AbsenceFormSheet(
        initial: absence,
        onSave: (dto) async {
          await _ds.update(absence.id, dto);
          if (mounted) Navigator.of(context).pop();
          _refresh();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ausência atualizada.')));
          }
        },
      ),
    );
  }

  Future<void> _delete(AbsenceDto absence) async {
    final confirm = await showConfirmDialog(
      context: context,
      title: 'Excluir ausencia',
      message: 'Deseja excluir esta ausencia?',
      confirmLabel: 'Excluir',
      danger: true,
    );
    if (!confirm) return;
    try {
      await _ds.delete(absence.id);
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ausência removida.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(extractDioError(e, 'Erro ao remover ausência.'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(absencesProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Header ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _Header(
                loading: async.isLoading,
                count: async.valueOrNull?.length,
                onAddTap: _openCreate,
              ),
            ),

            // ── Content ───────────────────────────────────────────────────
            async.when(
              loading: () => const SliverToBoxAdapter(child: _SkeletonList()),
              error: (e, _) => SliverToBoxAdapter(
                  child: _ErrorState(message: extractDioError(e))),
              data: (absences) {
                if (absences.isEmpty) {
                  return SliverToBoxAdapter(
                      child: _EmptyState(onAddTap: _openCreate));
                }
                final totalPages =
                    (absences.length / _pageSize).ceil().clamp(1, 999);
                final safePage = _page.clamp(1, totalPages);
                final start = (safePage - 1) * _pageSize;
                final paged = absences.skip(start).take(_pageSize).toList();
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      if (i == 0) {
                        return _AbsencePagerHeader(
                          pageSize: _pageSize,
                          options: _pageSizeOptions,
                          onChanged: (n) => setState(() {
                            _pageSize = n;
                            _page = 1;
                          }),
                        );
                      }
                      if (i == paged.length + 1) {
                        return _AbsencePagerFooter(
                          page: safePage,
                          totalPages: totalPages,
                          onPage: (p) => setState(() => _page = p),
                        );
                      }
                      final absence = paged[i - 1];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: _AbsenceCard(
                          absence: absence,
                          onEdit: () => _openEdit(absence),
                          onDelete: () => _delete(absence),
                        ),
                      );
                    },
                    childCount: paged.length + 2,
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

class _AbsencePagerHeader extends StatelessWidget {
  final int pageSize;
  final List<int> options;
  final ValueChanged<int> onChanged;

  const _AbsencePagerHeader({
    required this.pageSize,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('Por pagina',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.slate400 : AppColors.slate500,
              )),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: pageSize,
            isDense: true,
            dropdownColor: isDark ? AppColors.slate800 : Colors.white,
            items: options
                .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                .toList(),
            onChanged: (n) {
              if (n != null) onChanged(n);
            },
          ),
        ],
      ),
    );
  }
}

class _AbsencePagerFooter extends StatelessWidget {
  final int page;
  final int totalPages;
  final ValueChanged<int> onPage;

  const _AbsencePagerFooter({
    required this.page,
    required this.totalPages,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (totalPages <= 1) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: page <= 1 ? null : () => onPage(page - 1),
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Anterior'),
          ),
          const Spacer(),
          Text('Pagina $page de $totalPages',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.slate400 : AppColors.slate500,
              )),
          const Spacer(),
          TextButton.icon(
            onPressed: page >= totalPages ? null : () => onPage(page + 1),
            label: const Text('Proxima'),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool loading;
  final int? count;
  final VoidCallback onAddTap;

  const _Header({
    required this.loading,
    required this.count,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final n = count ?? 0;
    final subtitle = loading
        ? 'Carregando...'
        : '$n ausência${n != 1 ? 's' : ''} cadastrada${n != 1 ? 's' : ''}';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Row(
            children: [
              // Icon box
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withAlpha(50)),
                ),
                child: const Icon(Icons.event_busy_outlined,
                    size: 26, color: Colors.white),
              ),
              const SizedBox(width: 16),
              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ausências',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (loading)
                      const Row(children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.8, color: Colors.white),
                        ),
                        SizedBox(width: 6),
                        Text('Carregando...',
                            style:
                                TextStyle(color: Colors.white60, fontSize: 12)),
                      ])
                    else
                      Text(subtitle,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
              // Add button
              TextButton.icon(
                onPressed: onAddTap,
                icon: const Icon(Icons.add, size: 15, color: Colors.white),
                label: const Text('Nova ausência',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white)),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withAlpha(25),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.white.withAlpha(50))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Absence card ──────────────────────────────────────────────────────────────

class _AbsenceCard extends StatelessWidget {
  final AbsenceDto absence;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AbsenceCard({
    required this.absence,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMedical = absence.absenceType == 2;

    final dateLabel = absence.startDate == absence.endDate
        ? _formatDate(absence.startDate)
        : '${_formatDate(absence.startDate)} até ${_formatDate(absence.endDate)}';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppColors.slate200).withAlpha(80),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isMedical
                  ? AppColors.rose500.withAlpha(25)
                  : (isDark ? AppColors.slate700 : AppColors.slate100),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _absenceIcon(absence.absenceType),
              size: 18,
              color: isMedical
                  ? AppColors.rose500
                  : (isDark ? AppColors.slate400 : AppColors.slate500),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(absence.absenceTypeName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.slate900,
                    )),
                const SizedBox(height: 2),
                Text(dateLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.slate400 : AppColors.slate500,
                    )),
                if (absence.description != null &&
                    absence.description!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(absence.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.slate400 : AppColors.slate500,
                      )),
                ],
              ],
            ),
          ),

          // Actions
          Row(children: [
            _ActionButton(
              icon: Icons.edit_outlined,
              onTap: onEdit,
              isDark: isDark,
              isDelete: false,
            ),
            const SizedBox(width: 6),
            _ActionButton(
              icon: Icons.delete_outline,
              onTap: onDelete,
              isDark: isDark,
              isDelete: true,
            ),
          ]),
        ]),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  final bool isDelete;

  const _ActionButton({
    required this.icon,
    required this.onTap,
    required this.isDark,
    required this.isDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDelete
                ? AppColors.rose500.withAlpha(100)
                : (isDark ? AppColors.slate600 : AppColors.slate200),
          ),
        ),
        child: Icon(
          icon,
          size: 14,
          color: isDelete
              ? AppColors.rose500
              : (isDark ? AppColors.slate400 : AppColors.slate500),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddTap;
  const _EmptyState({required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate800 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? AppColors.slate700 : AppColors.slate200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_outlined,
                size: 40,
                color: isDark ? AppColors.slate600 : AppColors.slate300),
            const SizedBox(height: 12),
            Text('Nenhuma ausência cadastrada.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.slate400 : AppColors.slate500,
                )),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAddTap,
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Cadastrar ausência'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : AppColors.slate900,
                foregroundColor: isDark ? AppColors.slate900 : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 40, color: AppColors.rose500),
              const SizedBox(height: 10),
              const Text('Erro ao carregar ausências',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.slate400)),
              const SizedBox(height: 6),
              Text(message,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.slate500),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        const SizedBox(height: 16),
        for (var i = 0; i < 4; i++) ...[
          _SkeletonCard(isDark: isDark),
          const SizedBox(height: 8),
        ],
      ]),
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  final bool isDark;
  const _SkeletonCard({required this.isDark});
  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 0.9)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.isDark ? AppColors.slate800 : AppColors.slate100;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

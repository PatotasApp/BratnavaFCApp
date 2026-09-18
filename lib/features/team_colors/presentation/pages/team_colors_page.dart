import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/app_page_header.dart';
import '../../../../shared/presentation/widgets/no_active_group_view.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../data/datasources/team_color_remote_datasource.dart';
import '../../domain/entities/team_color.dart';
import '../providers/team_colors_provider.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

class TeamColorsPage extends ConsumerStatefulWidget {
  const TeamColorsPage({super.key});

  @override
  ConsumerState<TeamColorsPage> createState() => _TeamColorsPageState();
}

class _TeamColorsPageState extends ConsumerState<TeamColorsPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    // Fallback: usa groupId do player ativo se activeGroupId não estiver persistido.
    // O jogador manda no grupo: `activeGroupId` da conta pode apontar
    // para uma patota sem jogador nosso, e aí toda rota por grupo
    // responde 403. Ver dashboard_page para o diagnóstico completo.
    final groupId = account?.activeGroupId ?? activePlayer?.groupId;
    final groupIdNN = groupId; // non-null alias used in closures
    final canManage = account != null &&
        groupIdNN != null &&
        account.groupAdminIds.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async {
        if (groupIdNN != null) {
          ref.invalidate(teamColorsProvider(groupIdNN));
        }
      },
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _Header(
                groupId: groupId,
                canManage: canManage,
                onAdd: canManage
                    ? () => _openEditSheet(
                          context,
                          groupId: groupIdNN,
                          canManage: canManage,
                          isDark: isDark,
                        )
                    : null,
              ),
            ),

            if (groupId == null || groupId.isEmpty) ...[
              // Enquanto myPlayersProvider carrega, spinner em vez de "sem grupo"
              SliverFillRemaining(
                child: ref.watch(myPlayersProvider).isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : const NoActiveGroupView(
                        message: 'Selecione uma patota para ver os uniformes.',
                      ),
              ),
            ] else ...[
              SliverToBoxAdapter(
                child: _ColorsBody(
                  groupId: groupId,
                  isDark: isDark,
                  canManage: canManage,
                  selectedIndex: _selectedIndex,
                  onIndexChanged: (i) => setState(() => _selectedIndex = i),
                  onOpenPreview: (color) =>
                      _openPreview(context, color, isDark),
                  onOpenEdit: (color) => _openEditSheet(
                    context,
                    groupId: groupId,
                    canManage: canManage,
                    isDark: isDark,
                    existing: color,
                  ),
                  onActivate: (color) async {
                    final ds = ref.read(teamColorDsProvider);
                    try {
                      if (color.isActive) {
                        await ds.deactivateColor(groupId, color.id);
                      } else {
                        await ds.activateColor(groupId, color.id);
                      }
                      ref.invalidate(teamColorsProvider(groupId));
                    } catch (e) {
                      if (context.mounted) {
                        final msg = extractDioError(e);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg)),
                        );
                      }
                    }
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Preview bottom sheet ───────────────────────────────────────────────────

  void _openPreview(BuildContext context, TeamColor color, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.transparent,
      builder: (_) => _PreviewSheet(color: color, isDark: isDark),
    );
  }

  // ── Edit / Create bottom sheet ─────────────────────────────────────────────

  void _openEditSheet(
    BuildContext context, {
    required String groupId,
    required bool canManage,
    required bool isDark,
    TeamColor? existing,
  }) {
    if (!canManage) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => _EditSheet(
        groupId: groupId,
        existing: existing,
        isDark: isDark,
        onSaved: () => ref.invalidate(teamColorsProvider(groupId)),
        ds: ref.read(teamColorDsProvider),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  final String? groupId;
  final bool canManage;
  final VoidCallback? onAdd;

  const _Header({
    required this.groupId,
    required this.canManage,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorsAsync = groupId != null
        ? ref.watch(teamColorsProvider(groupId!))
        : const AsyncValue<List<TeamColor>>.data([]);

    final isLoading = colorsAsync.isLoading;
    final count = colorsAsync.valueOrNull?.where((c) => c.isActive).length ?? 0;

    final subtitle = isLoading
        ? 'Carregando uniformes...'
        : (groupId?.isEmpty ?? true)
            ? 'Uniformes usados pela sua patota'
            : '$count uniforme${count != 1 ? 's' : ''} disponível${count != 1 ? 'eis' : ''}';

    return AppPageHeader(
      title: 'Uniformes',
      subtitle: subtitle,
      icon: Icons.checkroom_rounded,
      footer: canManage && onAdd != null
          ? AppPageHeaderActionBar(
              actions: [
                AppPageHeaderButton(
                  label: 'Novo uniforme',
                  icon: Icons.add_rounded,
                  tone: AppPageHeaderButtonTone.primary,
                  onPressed: onAdd,
                ),
              ],
            )
          : null,
    );
  }
}

// ── Colors body (carousel + action bar) ──────────────────────────────────────

class _ColorsBody extends ConsumerWidget {
  final String groupId;
  final bool isDark;
  final bool canManage;
  final int selectedIndex;
  final void Function(int) onIndexChanged;
  final void Function(TeamColor) onOpenPreview;
  final void Function(TeamColor) onOpenEdit;
  final void Function(TeamColor) onActivate;

  const _ColorsBody({
    required this.groupId,
    required this.isDark,
    required this.canManage,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.onOpenPreview,
    required this.onOpenEdit,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teamColorsProvider(groupId));

    return async.when(
      loading: () => _CarouselSkeleton(isDark: isDark),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'Erro ao carregar: $e',
            style: TextStyle(
              color: isDark ? AppColors.slate400 : AppColors.slate500,
            ),
          ),
        ),
      ),
      data: (all) {
        // Non-admin sees only active colors
        final items = canManage ? all : all.where((c) => c.isActive).toList();

        if (items.isEmpty) {
          return _EmptyState(isDark: isDark);
        }

        final safeIndex = selectedIndex.clamp(0, items.length - 1);
        final selected = items[safeIndex];

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Uniforme selecionado',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Deslize para escolher outro uniforme',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton.outlined(
                      onPressed: () => onOpenPreview(selected),
                      tooltip: 'Visualizar uniforme',
                      icon: const Icon(Icons.visibility_outlined, size: 20),
                      style: IconButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Carousel ──────────────────────────────────────────
              _ColorCarousel(
                items: items,
                isDark: isDark,
                selectedIndex: safeIndex,
                onIndexChanged: onIndexChanged,
                onTap: onOpenPreview,
              ),

              // ── Action bar ─────────────────────────────────────────
              if (canManage) ...[
                Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                _ActionBar(
                  selected: selected,
                  isDark: isDark,
                  canManage: canManage,
                  onPreview: () => onOpenPreview(selected),
                  onEdit: () => onOpenEdit(selected),
                  onActivate: () => onActivate(selected),
                ),
              ] else
                const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

// ── Carousel ──────────────────────────────────────────────────────────────────

class _ColorCarousel extends StatefulWidget {
  final List<TeamColor> items;
  final bool isDark;
  final int selectedIndex;
  final void Function(int) onIndexChanged;
  final void Function(TeamColor) onTap;

  const _ColorCarousel({
    required this.items,
    required this.isDark,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.onTap,
  });

  @override
  State<_ColorCarousel> createState() => _ColorCarouselState();
}

class _ColorCarouselState extends State<_ColorCarousel> {
  late PageController _ctrl;

  // Large multiplier so the virtual list feels infinite in both directions.
  static const int _kMult = 10000;

  int get _midOffset => widget.items.length * (_kMult ~/ 2);

  @override
  void initState() {
    super.initState();
    final n = widget.items.length;
    _ctrl = PageController(
      viewportFraction: 0.84,
      initialPage: n <= 1 ? 0 : _midOffset + widget.selectedIndex,
    );
  }

  @override
  void didUpdateWidget(_ColorCarousel old) {
    super.didUpdateWidget(old);
    final n = widget.items.length;

    // Quando o número de itens muda (ex: 1→2), o controller precisa ser
    // recriado no mid-offset correto; caso contrário a navegação para a
    // esquerda ficaria presa em page=0 (limite inferior do PageView).
    if (old.items.length != n) {
      _ctrl.dispose();
      _ctrl = PageController(
        viewportFraction: 0.84,
        initialPage: n <= 1 ? 0 : _midOffset + widget.selectedIndex,
      );
      return;
    }

    if (old.selectedIndex != widget.selectedIndex && _ctrl.hasClients) {
      final currentVirtual = _ctrl.page?.round() ?? _midOffset;
      final currentReal = currentVirtual % n;
      if (currentReal != widget.selectedIndex) {
        // External selection change — jump to the nearest virtual page.
        final diff = (widget.selectedIndex - currentReal + n) % n;
        final target = diff <= n ~/ 2
            ? currentVirtual + diff
            : currentVirtual - (n - diff);
        _ctrl.animateToPage(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _goLeft() {
    final current = _ctrl.page?.round() ?? _midOffset;
    _ctrl.animateToPage(
      current - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goRight() {
    final current = _ctrl.page?.round() ?? _midOffset;
    _ctrl.animateToPage(
      current + 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final n = items.length;

    return Column(
      children: [
        SizedBox(
          height: 300,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  return PageView.builder(
                    controller: _ctrl,
                    clipBehavior: Clip.hardEdge,
                    physics:
                        n <= 1 ? const NeverScrollableScrollPhysics() : null,
                    itemCount: n <= 1 ? 1 : n * _kMult,
                    onPageChanged: (virtualIndex) =>
                        widget.onIndexChanged(virtualIndex % n),
                    itemBuilder: (context, virtualIndex) {
                      final realIndex = virtualIndex % n;
                      final color = items[realIndex];
                      final isSelected = realIndex == widget.selectedIndex;

                      double scale = 0.94;
                      if (_ctrl.hasClients && _ctrl.position.haveDimensions) {
                        final page = _ctrl.page ??
                            (n <= 1 ? 0 : _midOffset + widget.selectedIndex)
                                .toDouble();
                        final delta =
                            (page - virtualIndex).abs().clamp(0.0, 1.0);
                        scale = 1.0 - delta * 0.06;
                      } else {
                        scale = isSelected ? 1.0 : 0.94;
                      }

                      return Transform.scale(
                        scale: scale,
                        child: GestureDetector(
                          onTap: () {
                            if (isSelected) {
                              widget.onTap(color);
                            } else {
                              _ctrl.animateToPage(
                                virtualIndex,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          child: _ColorCard(
                            color: color,
                            isDark: widget.isDark,
                            isSelected: isSelected,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              if (n > 1) ...[
                // Left arrow
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _NavArrow(
                      icon: Icons.chevron_left_rounded,
                      enabled: true,
                      onTap: _goLeft,
                    ),
                  ),
                ),

                // Right arrow
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _NavArrow(
                      icon: Icons.chevron_right_rounded,
                      enabled: true,
                      onTap: _goRight,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Dot indicators
        const SizedBox(height: 8),
        _DotIndicators(
          count: items.length,
          selected: widget.selectedIndex,
          getColor: (i) => items[i].color,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Nav arrow ─────────────────────────────────────────────────────────────────

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _NavArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1.0 : 0.25,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: IconButton.filledTonal(
          onPressed: enabled ? onTap : null,
          tooltip: icon == Icons.chevron_left_rounded
              ? 'Uniforme anterior'
              : 'Próximo uniforme',
          style: IconButton.styleFrom(
            backgroundColor: scheme.surfaceContainerHighest,
            foregroundColor: scheme.onSurfaceVariant,
            side: BorderSide(color: scheme.outlineVariant),
          ),
          icon: Icon(icon, size: 20),
        ),
      ),
    );
  }
}

// ── Dot indicators ────────────────────────────────────────────────────────────

class _DotIndicators extends StatelessWidget {
  final int count;
  final int selected;
  final Color Function(int) getColor;

  const _DotIndicators({
    required this.count,
    required this.selected,
    required this.getColor,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isSel = i == selected;
        final c = isSel ? getColor(i) : AppColors.slate300;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isSel ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ── Color card ────────────────────────────────────────────────────────────────

class _ColorCard extends StatelessWidget {
  final TeamColor color;
  final bool isDark;
  final bool isSelected;

  const _ColorCard({
    required this.color,
    required this.isDark,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final teamColor = color.color;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? scheme.primary : scheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: isDark ? 0.16 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colored top strip
            Container(height: 4, color: teamColor),

            // Jersey stage — dark gradient like website
            Expanded(
              child: Container(
                color: scheme.surfaceContainerHighest,
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.62,
                    child: AspectRatio(
                      aspectRatio: 240 / 220,
                      child: _JerseyWidget(color: teamColor),
                    ),
                  ),
                ),
              ),
            ),

            // Info section — matches site layout
            Container(
              color: scheme.surface,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name row with badges
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          color.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (color.isActive)
                        _Badge(
                          label: 'Ativo',
                          bg: scheme.primaryContainer,
                          fg: scheme.onPrimaryContainer,
                        ),
                      if (isSelected) ...[
                        const SizedBox(width: 4),
                        _Badge(
                          label: 'Selecionado',
                          bg: scheme.primary,
                          fg: scheme.onPrimary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isSelected ? 'EM USO' : 'TOQUE PARA SELECIONAR',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color:
                          isSelected ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Jersey widget (CustomPainter) ─────────────────────────────────────────────

class _JerseyWidget extends StatelessWidget {
  final Color color;
  const _JerseyWidget({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _JerseyPainter(color: color),
    );
  }
}

class _JerseyPainter extends CustomPainter {
  final Color color;
  const _JerseyPainter({required this.color});

  // SVG viewBox: 0 0 240 220
  // Body path: M80 55 L105 40 L120 55 L135 40 L160 55 L185 70 L170 95 L160 90 L160 185 L80 185 L80 90 L70 95 L55 70 Z
  // Collar:    M105 40 L120 60 L135 40

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 240.0;
    final scaleY = size.height / 220.0;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    // Determine if color is light to adjust stroke
    final luminance = color.computeLuminance();
    final strokeColor = luminance > 0.7
        ? AppColors.darkBorder // dark stroke for light jerseys
        : AppColors.slate900; // very dark for colored jerseys

    // Jersey fill
    final bodyPath = Path()
      ..moveTo(80, 55)
      ..lineTo(105, 40)
      ..lineTo(120, 55)
      ..lineTo(135, 40)
      ..lineTo(160, 55)
      ..lineTo(185, 70)
      ..lineTo(170, 95)
      ..lineTo(160, 90)
      ..lineTo(160, 185)
      ..lineTo(80, 185)
      ..lineTo(80, 90)
      ..lineTo(70, 95)
      ..lineTo(55, 70)
      ..close();

    // Fill
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(bodyPath, fillPaint);

    // Stroke (body outline)
    final strokePaint = Paint()
      ..color = strokeColor.withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(bodyPath, strokePaint);

    // Collar (V-shape, stroke only)
    final collarPath = Path()
      ..moveTo(105, 40)
      ..lineTo(120, 60)
      ..lineTo(135, 40);

    final collarPaint = Paint()
      ..color = strokeColor.withAlpha(200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(collarPath, collarPaint);

    // Subtle inner highlight line along the shoulder seams
    final highlightPaint = Paint()
      ..color = AppColors.onDark.withAlpha(60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // Left seam highlight
    final leftSeam = Path()
      ..moveTo(80, 90)
      ..lineTo(70, 95)
      ..lineTo(55, 70)
      ..lineTo(80, 55);
    canvas.drawPath(leftSeam, highlightPaint);

    // Right seam highlight
    final rightSeam = Path()
      ..moveTo(160, 90)
      ..lineTo(170, 95)
      ..lineTo(185, 70)
      ..lineTo(160, 55);
    canvas.drawPath(rightSeam, highlightPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_JerseyPainter old) => old.color != color;
}

// ── Action bar ────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final TeamColor selected;
  final bool isDark;
  final bool canManage;
  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final VoidCallback onActivate;

  const _ActionBar({
    required this.selected,
    required this.isDark,
    required this.canManage,
    required this.onPreview,
    required this.onEdit,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: canManage
          ? Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Editar',
                    icon: Icons.edit_outlined,
                    isDark: isDark,
                    onTap: onEdit,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    label: selected.isActive ? 'Inativar' : 'Ativar',
                    icon: selected.isActive
                        ? Icons.power_settings_new_rounded
                        : Icons.check_circle_outline_rounded,
                    isDark: isDark,
                    accent: selected.isActive
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                    onTap: onActivate,
                  ),
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              child: _ActionButton(
                label: 'Ver uniforme',
                icon: Icons.visibility_outlined,
                isDark: isDark,
                onTap: onPreview,
              ),
            ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isDark;
  final Color? accent;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isDark,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = accent ?? scheme.onSurface;
    final bg = accent != null
        ? accent!.withValues(alpha: isDark ? 0.14 : 0.08)
        : scheme.surfaceContainerHighest;
    final border = accent ?? scheme.outlineVariant;

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border.withValues(alpha: 0.65)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Preview sheet ─────────────────────────────────────────────────────────────

class _PreviewSheet extends StatelessWidget {
  final TeamColor color;
  final bool isDark;

  const _PreviewSheet({required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final teamColor = color.color;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : AppColors.onDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colored top strip
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: teamColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),

            // Dark gradient header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.slate900,
                    Color.lerp(AppColors.darkCard, teamColor, 0.15)!,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Preview do uniforme',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.lightPlaceholder,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          color.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.onDark.withAlpha(20),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: AppColors.onDark.withAlpha(40)),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.onDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Jersey stage
            Container(
              height: 190,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.85,
                  colors: [
                    AppColors.onDark.withAlpha(isDark ? 30 : 80),
                    isDark ? AppColors.slate950 : AppColors.slate200,
                  ],
                ),
              ),
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: 0.55,
                  child: AspectRatio(
                    aspectRatio: 240 / 220,
                    child: _JerseyWidget(color: teamColor),
                  ),
                ),
              ),
            ),

            // Info footer
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Color swatch
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: teamColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppColors.slate700 : AppColors.slate200,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          color.hexValue.toUpperCase(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark ? AppColors.onDark : AppColors.slate900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          color.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.slate400
                                : AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  color.isActive
                      ? const _Badge(
                          label: 'Ativo',
                          bg: AppColors.emerald50,
                          fg: AppColors.primaryPressed,
                        )
                      : _Badge(
                          label: 'Inativo',
                          bg: isDark ? AppColors.slate800 : AppColors.slate100,
                          fg: isDark ? AppColors.slate400 : AppColors.slate500,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Edit / Create sheet ───────────────────────────────────────────────────────

class _EditSheet extends StatefulWidget {
  final String groupId;
  final TeamColor? existing;
  final bool isDark;
  final VoidCallback onSaved;
  final TeamColorRemoteDataSource ds;

  const _EditSheet({
    required this.groupId,
    required this.isDark,
    required this.onSaved,
    required this.ds,
    this.existing,
  });

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _hexCtrl;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  Color get _liveColor => _parseHex(_hexCtrl.text) ?? AppColors.lightBorder;

  static Color? _parseHex(String hex) {
    try {
      final h = hex.replaceAll('#', '').trim();
      if (h.length == 3) {
        final r = h[0] + h[0];
        final g = h[1] + h[1];
        final b = h[2] + h[2];
        return Color(int.parse('FF$r$g$b', radix: 16));
      }
      if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    } catch (_) {}
    return null;
  }

  void _onPickerColorChanged(Color c) {
    final r = ((c.r * 255).round()).toRadixString(16).padLeft(2, '0');
    final g = ((c.g * 255).round()).toRadixString(16).padLeft(2, '0');
    final b = ((c.b * 255).round()).toRadixString(16).padLeft(2, '0');
    _hexCtrl.text = '#$r$g$b';
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _hexCtrl = TextEditingController(
      text: widget.existing?.hexValue ?? '#3b82f6',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hexCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final hex = _hexCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome é obrigatório')),
      );
      return;
    }
    if (_parseHex(hex) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cor inválida. Use formato #rrggbb')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final normalizedHex = hex.startsWith('#') ? hex : '#$hex';
      if (_isEdit) {
        await widget.ds.updateColor(
            widget.groupId, widget.existing!.id, name, normalizedHex);
      } else {
        await widget.ds.createColor(widget.groupId, name, normalizedHex);
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(extractDioError(e))),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return AnimatedBuilder(
      animation: Listenable.merge([_nameCtrl, _hexCtrl]),
      builder: (context, _) {
        final liveC = _liveColor;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate900 : AppColors.onDark,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Colored top strip
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 3,
                    decoration: BoxDecoration(
                      color: liveC,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                  ),

                  // Dark gradient header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.slate900,
                          Color.lerp(AppColors.darkCard, liveC, 0.2)!,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.onDark.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.onDark.withAlpha(40)),
                          ),
                          child: const Icon(
                            Icons.palette_rounded,
                            size: 18,
                            color: AppColors.onDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isEdit ? 'EDITAR COR' : 'NOVA COR',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.lightPlaceholder,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _nameCtrl.text.isEmpty
                                    ? (_isEdit ? 'Editar cor' : 'Nova cor')
                                    : _nameCtrl.text,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.onDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.onDark.withAlpha(20),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.onDark.withAlpha(40)),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: AppColors.onDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Scrollable body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Mini jersey preview card
                          Container(
                            height: 130,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.slate700
                                    : AppColors.slate200,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Row(
                                children: [
                                  // Jersey stage — dark gradient like website
                                  Expanded(
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            AppColors.lightTextSecondary,
                                            AppColors.lightText
                                          ],
                                        ),
                                      ),
                                      child: Center(
                                        child: FractionallySizedBox(
                                          widthFactor: 0.55,
                                          child: AspectRatio(
                                            aspectRatio: 240 / 220,
                                            child: _JerseyWidget(color: liveC),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Info sidebar
                                  Container(
                                    color: isDark
                                        ? AppColors.slate800
                                        : AppColors.slate50,
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: liveC,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isDark
                                                  ? AppColors.slate600
                                                  : AppColors.slate300,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _hexCtrl.text.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? AppColors.slate300
                                                : AppColors.slate700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _nameCtrl.text.isEmpty
                                              ? '—'
                                              : _nameCtrl.text,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isDark
                                                ? AppColors.slate500
                                                : AppColors.slate400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Inline color picker
                          Text(
                            'ESCOLHER COR',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: isDark
                                  ? AppColors.slate500
                                  : AppColors.slate400,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ColorPicker(
                            pickerColor: liveC,
                            onColorChanged: _onPickerColorChanged,
                            enableAlpha: false,
                            displayThumbColor: true,
                            pickerAreaHeightPercent: 0.45,
                            hexInputBar: false,
                            labelTypes: const [],
                          ),

                          const SizedBox(height: 12),

                          // Name field
                          _label('Nome', isDark),
                          const SizedBox(height: 6),
                          _field(
                            controller: _nameCtrl,
                            hint: 'Ex: Azul Royal',
                            isDark: isDark,
                          ),

                          const SizedBox(height: 14),

                          // Hex field with color swatch
                          _label('Hex (RGB)', isDark),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: _field(
                                  controller: _hexCtrl,
                                  hint: '#rrggbb',
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 10),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: liveC,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.slate600
                                        : AppColors.slate300,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),
                          Text(
                            _isEdit
                                ? 'Atualiza nome e cor do uniforme selecionado.'
                                : 'Cria uma nova cor no grupo.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.slate500
                                  : AppColors.slate400,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: isDark
                                          ? AppColors.slate700
                                          : AppColors.slate200,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                  ),
                                  child: Text(
                                    'Cancelar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.slate400
                                          : AppColors.slate500,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _saving ? null : _save,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: isDark
                                        ? AppColors.onDark
                                        : AppColors.slate900,
                                    foregroundColor: isDark
                                        ? AppColors.slate900
                                        : AppColors.onDark,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                  ),
                                  child: _saving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.onDark,
                                          ),
                                        )
                                      : const Text(
                                          'Salvar',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _label(String text, bool isDark) => Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.slate400 : AppColors.slate500,
          letterSpacing: .3,
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(
        fontSize: 14,
        color: isDark ? AppColors.slate200 : AppColors.slate800,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: isDark ? AppColors.slate600 : AppColors.slate400),
        filled: true,
        fillColor: isDark ? AppColors.slate800 : AppColors.slate50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.slate700 : AppColors.slate200,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.slate700 : AppColors.slate200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.slate400 : AppColors.slate500,
            width: 1.5,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 48),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : AppColors.onDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.slate700 : AppColors.slate200,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.palette_outlined,
              size: 36,
              color: isDark ? AppColors.slate600 : AppColors.slate300,
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhuma cor cadastrada.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.slate400 : AppColors.slate500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Adicione cores para personalizar os uniformes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.slate500 : AppColors.slate400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Carousel skeleton ─────────────────────────────────────────────────────────

class _CarouselSkeleton extends StatelessWidget {
  final bool isDark;
  const _CarouselSkeleton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Container(
            height: 290,
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800 : AppColors.slate100,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (i) => Container(
                width: i == 1 ? 20 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate700 : AppColors.slate200,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Badge ─────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _Badge({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: fg.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

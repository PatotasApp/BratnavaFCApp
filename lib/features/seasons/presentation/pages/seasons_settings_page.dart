import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../shared/presentation/widgets/app_page_header.dart';
import '../../../../shared/presentation/widgets/confirm_dialog.dart';
import '../../../../shared/presentation/widgets/no_active_group_view.dart';
import '../../domain/season_models.dart';
import '../providers/seasons_provider.dart';

final _fmt = DateFormat('dd/MM/yyyy HH:mm');

/// Temporadas da patota (admin): fechar e abrir a próxima, renomear, marcar
/// pré-temporada, ajustar o corte e desfazer o último fechamento. Vale na hora.
class SeasonsSettingsPage extends ConsumerStatefulWidget {
  const SeasonsSettingsPage({super.key});

  @override
  ConsumerState<SeasonsSettingsPage> createState() => _SeasonsSettingsPageState();
}

class _SeasonsSettingsPageState extends ConsumerState<SeasonsSettingsPage> {
  bool _busy = false;

  Future<void> _run(String groupId, Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(seasonsProvider(groupId));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(extractDioError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupId = ref.watch(seasonsGroupIdProvider);
    return Scaffold(
      body: Column(
        children: [
          AppPageHeader(
            title: 'Temporadas',
            subtitle: 'Fechar, renomear e pré-temporada',
            icon: Icons.date_range_outlined,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: groupId.isEmpty
                ? const NoActiveGroupView(message: 'Selecione uma patota.')
                : ref.watch(seasonsProvider(groupId)).when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text(extractDioError(e))),
                      data: (data) => _body(context, groupId, data),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, String groupId, SeasonsOverview data) {
    final ds = ref.read(seasonsDatasourceProvider);
    final open = data.open;
    final years = data.seasons.map((s) => s.year).toSet().toList()..sort((a, b) => b.compareTo(a));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
      children: [
        Text(
          'Cada partida entra na temporada pela data do jogo. Fechar uma temporada abre a próxima a partir do corte.\n'
          '${data.manualMode ? 'A temporada não vira sozinha no ano novo: abra a próxima quando quiser.' : 'Enquanto ninguém fechar uma temporada, ela vira sozinha no ano novo.'}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (data.openSeasonFromPastYear) ...[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('${open!.displayName} ainda está aberta e o ano já virou. Abra a temporada de ${DateTime.now().year}.'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (open != null)
          FilledButton.icon(
            onPressed: _busy ? null : () => _close(context, groupId, open),
            icon: const Icon(Icons.flag_outlined),
            label: Text('Fechar ${open.displayName} e abrir a próxima'),
          ),
        if (data.canUndoClose)
          TextButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    final ok = await showConfirmDialog(
                      context: context,
                      title: 'Desfazer último fechamento',
                      message: '${open?.displayName ?? 'A temporada aberta'} é apagada e a anterior volta a ficar aberta.',
                      confirmLabel: 'Desfazer',
                      danger: true,
                    );
                    if (ok) await _run(groupId, () => ds.undoClose(groupId), 'Fechamento desfeito.');
                  },
            icon: const Icon(Icons.undo),
            label: const Text('Desfazer último fechamento'),
          ),
        for (final year in years) ...[
          const SizedBox(height: 16),
          Text('$year', style: Theme.of(context).textTheme.labelLarge),
          for (final season in data.seasons.where((s) => s.year == year).toList().reversed)
            _SeasonTile(
              season: season,
              busy: _busy,
              canMoveStart: season.id != data.seasons.first.id,
              onEdit: () => _edit(context, groupId, season, canMoveStart: season.id != data.seasons.first.id),
            ),
        ],
      ],
    );
  }

  Future<void> _close(BuildContext context, String groupId, Season open) async {
    final result = await showModalBottomSheet<_CloseInput>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CloseSheet(groupId: groupId),
    );
    if (result == null) return;
    final ds = ref.read(seasonsDatasourceProvider);
    await _run(
      groupId,
      () => ds.close(groupId, cutAt: result.cutAt, nextName: result.nextName, nextIsPreSeason: result.isPreSeason),
      'Temporada fechada. A próxima já está aberta.',
    );
  }

  Future<void> _edit(BuildContext context, String groupId, Season season, {required bool canMoveStart}) async {
    final name = TextEditingController(text: season.name ?? '');
    var isPre = season.isPreSeason;
    var start = season.startsAt.toLocal();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: Text('Editar ${season.displayName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                maxLength: 40,
                decoration: InputDecoration(labelText: 'Nome', hintText: 'Padrão: ${season.year}/${season.number}'),
              ),
              if (canMoveStart)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Início (corte com a anterior)'),
                  subtitle: Text(_fmt.format(start)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () async {
                    final picked = await _pickDateTime(dialogContext, start);
                    if (picked != null) setLocal(() => start = picked);
                  },
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: isPre,
                onChanged: (v) => setLocal(() => isPre = v),
                title: const Text('É pré-temporada'),
                subtitle: const Text('Conta na carreira, mas não entra nos filtros e títulos do ano'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Salvar')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final ds = ref.read(seasonsDatasourceProvider);
    await _run(groupId, () async {
      if (canMoveStart && start != season.startsAt.toLocal()) await ds.moveStart(groupId, season.id, start);
      await ds.update(groupId, season.id, name: name.text.trim().isEmpty ? null : name.text.trim(), isPreSeason: isPre);
    }, 'Temporada salva.');
  }
}

class _SeasonTile extends StatelessWidget {
  final Season season;
  final bool busy;
  final bool canMoveStart;
  final VoidCallback onEdit;

  const _SeasonTile({required this.season, required this.busy, required this.canMoveStart, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: season.isCurrent ? colors.primaryContainer.withValues(alpha: 0.4) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(season.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (season.isCurrent) const Chip(label: Text('Atual'), visualDensity: VisualDensity.compact),
                      if (season.isPreSeason) const Chip(label: Text('Pré-temporada'), visualDensity: VisualDensity.compact),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Editar ${season.displayName}',
                  onPressed: busy ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            Text(
              '${_fmt.format(season.startsAt.toLocal())} → ${season.endsAt == null ? 'aberta' : _fmt.format(season.endsAt!.toLocal())}'
              ' · ${season.matches} partida${season.matches == 1 ? '' : 's'}'
              '${season.championships > 0 ? ' · ${season.championships} campeonato${season.championships == 1 ? '' : 's'}' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (season.closedByName != null && season.closedAt != null)
              Text('Fechada por ${season.closedByName} em ${_fmt.format(season.closedAt!.toLocal())}',
                  style: Theme.of(context).textTheme.bodySmall),
            if (season.hasEnded)
              TextButton.icon(
                onPressed: () => context.push('/app/seasons/${season.id}'),
                icon: const Icon(Icons.emoji_events_outlined, size: 18),
                label: const Text('Ver retrospectiva'),
              ),
          ],
        ),
      ),
    );
  }
}

class _CloseInput {
  final DateTime cutAt;
  final String? nextName;
  final bool isPreSeason;
  const _CloseInput(this.cutAt, this.nextName, this.isPreSeason);
}

/// Fechamento com resumo recalculado a cada corte: quantos jogos ficam em cada temporada.
class _CloseSheet extends ConsumerStatefulWidget {
  final String groupId;
  const _CloseSheet({required this.groupId});

  @override
  ConsumerState<_CloseSheet> createState() => _CloseSheetState();
}

class _CloseSheetState extends ConsumerState<_CloseSheet> {
  DateTime _cut = DateTime.now();
  final _name = TextEditingController();
  bool _isPre = false;
  SeasonClosePreview? _preview;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPreview());
  }

  Future<void> _loadPreview() async {
    try {
      final preview = await ref.read(seasonsDatasourceProvider).closePreview(widget.groupId, _cut);
      if (mounted) setState(() { _preview = preview; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _preview = null; _error = extractDioError(e); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Fechar temporada', style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Corte (a próxima começa aqui)'),
            subtitle: Text(_fmt.format(_cut)),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: () async {
              final picked = await _pickDateTime(context, _cut);
              if (picked != null) {
                setState(() => _cut = picked);
                await _loadPreview();
              }
            },
          ),
          TextField(
            controller: _name,
            maxLength: 40,
            decoration: InputDecoration(labelText: 'Nome da próxima', hintText: p == null ? null : 'Padrão: ${p.nextDefaultName}'),
            onChanged: (_) => setState(() {}),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isPre,
            onChanged: (v) => setState(() => _isPre = v),
            title: const Text('A próxima é pré-temporada'),
          ),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (p != null)
            Text(
              'Fecha ${p.closingDisplayName} (${_fmt.format(p.closingStartsAt.toLocal())} → ${_fmt.format(p.cutAt.toLocal())}): '
              '${p.closingMatches} partida${p.closingMatches == 1 ? '' : 's'}'
              '${p.closingChampionships > 0 ? ' e ${p.closingChampionships} campeonato${p.closingChampionships == 1 ? '' : 's'}' : ''}.\n'
              'Abre ${_name.text.trim().isEmpty ? p.nextDefaultName : _name.text.trim()}, que pertence a ${p.nextYear}.'
              '${p.movedMatches + p.movedChampionships > 0 ? '\n${p.movedMatches} partida(s) e ${p.movedChampionships} campeonato(s) depois do corte vão para a nova temporada.' : ''}',
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: p == null
                ? null
                : () => Navigator.pop(context, _CloseInput(_cut, _name.text.trim().isEmpty ? null : _name.text.trim(), _isPre)),
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Confirmar fechamento'),
          ),
        ],
      ),
    );
  }
}

Future<DateTime?> _pickDateTime(BuildContext context, DateTime initial) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime.now().add(const Duration(days: 31)),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

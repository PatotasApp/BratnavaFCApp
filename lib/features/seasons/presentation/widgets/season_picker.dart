import 'package:flutter/material.dart';
import '../../domain/season_models.dart';

/// Seletor único de temporada (estatísticas, histórico, conquistas). Em [seasonsOnly]
/// só há temporadas (o "na temporada" das conquistas); senão também o ano e "todas".
class SeasonPicker extends StatelessWidget {
  final SeasonsOverview? overview;
  final SeasonSelection value;
  final ValueChanged<SeasonSelection> onChanged;
  final bool seasonsOnly;

  const SeasonPicker({
    super.key,
    required this.overview,
    required this.value,
    required this.onChanged,
    this.seasonsOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final data = overview;
    if (data == null || data.seasons.isEmpty) return const SizedBox.shrink();

    final current = data.current;
    final years = data.seasons.map((s) => s.year).toSet().toList()..sort((a, b) => b.compareTo(a));
    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem(
        value: 'current',
        child: Text('Temporada atual${current != null ? ' (${current.displayName})' : ''}'),
      ),
    ];
    for (final year in years) {
      final ofYear = data.seasons.where((s) => s.year == year).toList().reversed.toList();
      final hasPreSeason = ofYear.any((s) => s.isPreSeason);
      items.add(DropdownMenuItem(
        enabled: false,
        value: 'header:$year',
        child: Text('$year', style: Theme.of(context).textTheme.labelSmall),
      ));
      for (final s in ofYear) {
        items.add(DropdownMenuItem(
          value: SeasonPick(s.id).key,
          child: Text('   ${s.displayName}${s.isPreSeason ? ' · pré-temporada' : ''}'),
        ));
      }
      if (!seasonsOnly && ofYear.length > 1) {
        items.add(DropdownMenuItem(
          value: YearPick(year, includePreSeason: false).key,
          child: Text('   Ano $year inteiro${hasPreSeason ? ' (sem pré-temporada)' : ''}'),
        ));
      }
      if (!seasonsOnly && hasPreSeason) {
        items.add(DropdownMenuItem(
          value: YearPick(year, includePreSeason: true).key,
          child: Text('   Ano $year com pré-temporada'),
        ));
      }
    }
    if (!seasonsOnly) {
      items.add(const DropdownMenuItem(value: 'all', child: Text('Todas as temporadas')));
    }

    final selected = items.any((i) => i.value == value.key) ? value.key : 'current';
    return Row(
      children: [
        const Icon(Icons.date_range_outlined, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButton<String>(
            key: const Key('season-picker'),
            isExpanded: true,
            value: selected,
            items: items,
            onChanged: (key) {
              if (key != null && !key.startsWith('header:')) onChanged(SeasonSelection.parse(key));
            },
          ),
        ),
      ],
    );
  }
}

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
    final years = data.seasons.map((s) => s.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem(
        value: 'current',
        child: Text(
            'Temporada atual${current != null ? ' (${current.displayName})' : ''}'),
      ),
    ];
    for (final year in years) {
      final ofYear =
          data.seasons.where((s) => s.year == year).toList().reversed.toList();
      final hasPreSeason = ofYear.any((s) => s.isPreSeason);
      items.add(DropdownMenuItem(
        enabled: false,
        value: 'header:$year',
        child: Text('$year', style: Theme.of(context).textTheme.labelSmall),
      ));
      for (final s in ofYear) {
        items.add(DropdownMenuItem(
          value: SeasonPick(s.id).key,
          child: Text(
              '   ${s.displayName}${s.isPreSeason ? ' · pré-temporada' : ''}'),
        ));
      }
      if (!seasonsOnly && ofYear.length > 1) {
        items.add(DropdownMenuItem(
          value: YearPick(year, includePreSeason: false).key,
          child: Text(
              '   Ano $year inteiro${hasPreSeason ? ' (sem pré-temporada)' : ''}'),
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
      items.add(const DropdownMenuItem(
          value: 'all', child: Text('Todas as temporadas')));
    }

    final selected =
        items.any((i) => i.value == value.key) ? value.key : 'current';
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
              if (key != null && !key.startsWith('header:'))
                onChanged(SeasonSelection.parse(key));
            },
          ),
        ),
      ],
    );
  }
}

/// Seletor em dois níveis para telas de estatísticas: primeiro o ano, depois o
/// período daquele ano. A primeira opção do período sempre representa o ano
/// completo, incluindo pré-temporadas.
class SeasonYearPicker extends StatelessWidget {
  final SeasonsOverview? overview;
  final SeasonSelection value;
  final ValueChanged<SeasonSelection> onChanged;

  const SeasonYearPicker({
    super.key,
    required this.overview,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final data = overview;
    if (data == null || data.seasons.isEmpty) return const SizedBox.shrink();

    final years = data.seasons.map((s) => s.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    final pickedSeason = value.seasonIn(data);
    final selectedYear = switch (value) {
      YearPick(:final year) => year,
      SeasonPick() => pickedSeason?.year,
      CurrentSeason() => data.current?.year,
      AllSeasons() => null,
    };
    final yearValue = selectedYear != null && years.contains(selectedYear)
        ? '$selectedYear'
        : 'all';

    final periods = selectedYear == null
        ? const <Season>[]
        : (data.seasons.where((s) => s.year == selectedYear).toList()
          ..sort((a, b) => b.startsAt.compareTo(a.startsAt)));
    final completeYear = selectedYear == null
        ? const AllSeasons()
        : YearPick(selectedYear, includePreSeason: true);
    final periodValue = switch (value) {
      SeasonPick() when pickedSeason?.year == selectedYear => value.key,
      CurrentSeason() when data.current?.year == selectedYear =>
        SeasonPick(data.current!.id).key,
      _ => completeYear.key,
    };

    final yearDropdown = DropdownButtonFormField<String>(
      key: const Key('season-year-picker'),
      initialValue: yearValue,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Ano',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      items: [
        for (final year in years)
          DropdownMenuItem(value: '$year', child: Text('$year')),
        const DropdownMenuItem(value: 'all', child: Text('Todos os anos')),
      ],
      onChanged: (next) {
        if (next == null) return;
        onChanged(next == 'all'
            ? const AllSeasons()
            : YearPick(int.parse(next), includePreSeason: true));
      },
    );

    final periodDropdown = DropdownButtonFormField<String>(
      key: const Key('season-period-picker'),
      initialValue: periodValue,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Período',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      items: selectedYear == null
          ? const [
              DropdownMenuItem(
                value: 'all',
                child: Text('Todas as temporadas'),
              ),
            ]
          : [
              DropdownMenuItem(
                value: completeYear.key,
                child: const Text('Ano completo'),
              ),
              for (final season in periods)
                DropdownMenuItem(
                  value: SeasonPick(season.id).key,
                  child: Text(
                    '${season.displayName}${season.isPreSeason ? ' · pré' : ''}',
                  ),
                ),
            ],
      onChanged: selectedYear == null
          ? null
          : (next) {
              if (next != null) onChanged(SeasonSelection.parse(next));
            },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 390) {
          return Column(
            children: [
              yearDropdown,
              const SizedBox(height: 10),
              periodDropdown,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: yearDropdown),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: periodDropdown),
          ],
        );
      },
    );
  }
}

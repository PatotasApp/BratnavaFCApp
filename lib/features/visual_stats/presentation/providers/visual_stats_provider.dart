import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/visual_stats_datasource.dart';
import '../../domain/entities/visual_stats_report.dart';

final visualStatsDsProvider = Provider<VisualStatsDatasource>(
  (ref) => VisualStatsDatasource(ref.watch(dioProvider)),
);

/// [period]: chave estável da temporada escolhida (ver SeasonSelection), traduzida
/// para parâmetros com [periodParams]. Vazio = tudo.
typedef VisualStatsArgs = ({String groupId, bool includeGuests, String period});

final visualStatsProvider =
    FutureProvider.autoDispose.family<PlayerVisualStatsReport, VisualStatsArgs>(
  (ref, args) => ref.watch(visualStatsDsProvider).fetchVisualStats(
        args.groupId,
        includeGuests: args.includeGuests,
        period: periodParams(args.period),
      ),
);

/// "seasonId=x" | "year=2026&includePreSeason=false" | "" → parâmetros da API.
Map<String, String> periodParams(String period) =>
    period.isEmpty ? const {} : Uri.splitQueryString(period);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../data/seasons_datasource.dart';
import '../../domain/season_models.dart';

final seasonsDatasourceProvider = Provider<SeasonsDatasource>(
  (ref) => SeasonsDatasource(ref.watch(dioProvider)),
);

/// Patota ativa das telas de temporada ('' sem patota); sobrescrito nos testes.
final seasonsGroupIdProvider = Provider<String>((ref) {
  final account = ref.watch(accountStoreProvider).activeAccount;
  final player = ref.watch(activePlayerProvider);
  return account?.activeGroupId ?? player?.groupId ?? '';
});

/// Temporadas da patota.
final seasonsProvider =
    FutureProvider.autoDispose.family<SeasonsOverview, String>(
  (ref, groupId) => ref.watch(seasonsDatasourceProvider).list(groupId),
);

/// Temporadas já carregadas (null enquanto carrega ou se falhar: a tela segue sem filtro).
SeasonsOverview? seasonsOrNull(AsyncValue<SeasonsOverview> value) =>
    value.valueOrNull;

typedef SeasonSummaryArgs = ({String groupId, String seasonId});

final seasonSummaryProvider =
    FutureProvider.autoDispose.family<SeasonSummary, SeasonSummaryArgs>(
  (ref, args) =>
      ref.watch(seasonsDatasourceProvider).summary(args.groupId, args.seasonId),
);

/// Escolha do seletor por tela e patota ('stats:<groupId>', 'conquistas:<groupId>'...),
/// lembrada enquanto o app estiver aberto.
final seasonSelectionProvider = StateProvider.family<SeasonSelection, String>(
  (ref, key) => const CurrentSeason(),
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/discovery_datasource.dart';

/// Há convite ou partida em andamento para quem não tem patota (candidatura em
/// análise, convite a responder, ou partida confirmada que ainda não acabou)?
/// Usado só para decidir se mostra o atalho para "Convites para jogar".
final hasMatchInvitesInProgressProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  try {
    final items =
        await DiscoveryDataSource(ref.read(dioProvider)).myApplications();
    return items.any((x) =>
        (x.status == 3 && x.matchStatus < 4) ||
        ((x.status == 1 || x.status == 2) && x.matchStatus <= 1));
  } catch (_) {
    return false;
  }
});

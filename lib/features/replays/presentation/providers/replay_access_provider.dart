import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/replay_access.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';

/// Fonte única para decidir se recursos visuais de replay aparecem no app.
/// A regra usa o ID estável da patota, independentemente do nome atual.
final activeGroupReplayUiProvider = Provider<bool>((ref) {
  final activePlayer = ref.watch(activePlayerProvider);
  final account = ref.watch(accountStoreProvider).activeAccount;
  return groupHasReplays(activePlayer?.groupId ?? account?.activeGroupId);
});

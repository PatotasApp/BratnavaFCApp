import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../providers/match_provider.dart';

class Step5EncerrarPage extends ConsumerWidget {
  const Step5EncerrarPage({super.key});

  bool _isAdmin(WidgetRef ref) {
    final acc = ref.read(accountStoreProvider).activeAccount;
    final gid = acc?.activeGroupId ?? '';
    return (acc?.isAdmin ?? false) ||
        (gid.isNotEmpty && (acc?.isGroupAdmin(gid) ?? false));
  }

  Future<void> _goPostGame(BuildContext context, WidgetRef ref) async {
    await ref.read(matchNotifierProvider.notifier).goToPostGame();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(matchNotifierProvider);
    final isAdmin = _isAdmin(ref);
    final fmt = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
    final dateStr = s.playedAt != null ? fmt.format(s.playedAt!) : '-';
    final endedMessage = isAdmin
        ? 'Partida encerrada. Avance para registrar placar e MVP.'
        : 'Partida encerrada. Aguardando admin ir para Pós-jogo.';

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side:
                        const BorderSide(color: AppColors.warning, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.amber200,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Encerrado',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.warningLight,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: AppColors.slate400,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              dateStr,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 16,
                              color: AppColors.slate400,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                s.placeName ?? '-',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.amber50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 16,
                                color: AppColors.amber500,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  endedMessage,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.warningLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isAdmin)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      s.mutating ? null : () => _goPostGame(context, ref),
                  icon: s.mutating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onDark,
                          ),
                        )
                      : const Icon(Icons.arrow_forward),
                  label: const Text('Pós-jogo'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

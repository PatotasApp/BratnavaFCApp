import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/participation_history_item.dart';

Future<void> showParticipationHistorySheet({
  required BuildContext context,
  required String playerName,
  required Future<List<ParticipationHistoryItem>> history,
}) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => FutureBuilder<List<ParticipationHistoryItem>>(
        future: history,
        builder: (context, snapshot) {
          final items = snapshot.data;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                      child: Text('Histórico de $playerName',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800))),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded)),
                ]),
                const Text(
                    'Todas as mudanças ficam registradas com data e hora.'),
                const SizedBox(height: 16),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (snapshot.hasError)
                  Text(
                      'Não foi possível carregar o histórico. ${snapshot.error}')
                else if (items == null || items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('Ainda não há ações registradas.',
                        textAlign: TextAlign.center),
                  )
                else
                  Flexible(
                      child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, index) {
                      final item = items[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.history_rounded),
                        title: Text(item.label),
                        subtitle: Text([
                          DateFormat('dd/MM/yyyy HH:mm')
                              .format(item.occurredAt),
                          if (item.performedByAdmin)
                            'Alterado pelo administrador',
                          if (item.details?.trim().isNotEmpty == true)
                            item.details!,
                        ].join(' · ')),
                      );
                    },
                  )),
              ],
            ),
          );
        },
      ),
    );

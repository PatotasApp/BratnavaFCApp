import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../../features/auth/presentation/providers/account_store.dart';
import '../constants/app_constants.dart';

class BratnavaRealtimeEvent {
  final String type;
  final String groupId;
  final String? matchId;
  final String? pollId;
  final String reason;
  final DateTime? occurredAtUtc;

  const BratnavaRealtimeEvent({
    required this.type,
    required this.groupId,
    this.matchId,
    this.pollId,
    required this.reason,
    this.occurredAtUtc,
  });

  factory BratnavaRealtimeEvent.fromJson(Map<String, dynamic> json) {
    return BratnavaRealtimeEvent(
      type: (json['type'] ?? json['Type'] ?? '').toString(),
      groupId: (json['groupId'] ?? json['GroupId'] ?? '').toString(),
      matchId: (json['matchId'] ?? json['MatchId'])?.toString(),
      pollId: (json['pollId'] ?? json['PollId'])?.toString(),
      reason: (json['reason'] ?? json['Reason'] ?? '').toString(),
      occurredAtUtc: DateTime.tryParse(
        (json['occurredAtUtc'] ?? json['OccurredAtUtc'] ?? '').toString(),
      ),
    );
  }
}

final realtimeEventsProvider =
    StreamProvider.autoDispose.family<BratnavaRealtimeEvent, String>(
  (ref, groupId) {
    final account = ref.watch(accountStoreProvider).activeAccount;
    final token = account?.accessToken;
    final controller = StreamController<BratnavaRealtimeEvent>.broadcast();

    if (groupId.isEmpty || token == null || token.isEmpty) {
      controller.close();
      return controller.stream;
    }

    final url =
        '${AppConstants.apiUrl.replaceAll(RegExp(r"/+$"), "")}/hubs/realtime';
    final connection = HubConnectionBuilder()
        .withUrl(
          url,
          options: HttpConnectionOptions(
            accessTokenFactory: () async =>
                ref.read(accountStoreProvider).activeAccount?.accessToken ??
                token,
          ),
        )
        .withAutomaticReconnect()
        .build();

    Future<void> join() async {
      if (connection.state != HubConnectionState.Connected) return;
      try {
        await connection.invoke('JoinGroup', args: [groupId]);
      } catch (_) {}
    }

    connection.on('RealtimeEvent', (args) {
      final raw = args == null || args.isEmpty ? null : args.first;
      if (raw is! Map) return;
      final event = BratnavaRealtimeEvent.fromJson(
        raw.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (event.groupId.toLowerCase() != groupId.toLowerCase()) return;
      if (!controller.isClosed) controller.add(event);
    });

    connection.onreconnected(({connectionId}) {
      unawaited(join());
    });

    connection.start()?.then((_) => join()).catchError((_) {});

    ref.onDispose(() {
      controller.close();
      unawaited(connection.stop());
    });

    return controller.stream;
  },
);

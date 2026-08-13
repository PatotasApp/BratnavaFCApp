import 'package:patotas_app/features/polls/domain/entities/poll_summary.dart';
import 'package:patotas_app/features/polls/presentation/widgets/event_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('event card adapts to narrow screens without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const poll = PollSummary(
      id: 'event-1',
      title: 'Encerramento da patota com um título mais comprido',
      description: 'Um encontro importante para todos os participantes',
      allowMultipleVotes: false,
      showVotes: true,
      status: 'open',
      deadlineDate: '2099-11-16',
      deadlineTime: '12:00',
      optionCount: 3,
      totalVoters: 14,
      hasVoted: true,
      createDate: '2099-08-11',
      type: 'event',
      eventDate: '2099-11-21',
      eventLocation: 'R. Antônio Paulo Leite - Progresso',
      eventIcon: '🎉',
      allowGuests: true,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EventCard(poll: poll, onTap: _noop),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Respondeu'), findsOneWidget);
    expect(find.text('Aberto'), findsOneWidget);
    expect(find.text('Convidados'), findsOneWidget);
    expect(find.text('21/11/2099'), findsOneWidget);
  });
}

void _noop() {}

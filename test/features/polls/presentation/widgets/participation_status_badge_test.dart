import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/polls/presentation/widgets/participation_status_badge.dart';

void main() {
  Future<void> pumpBadge(WidgetTester tester, {required bool hasVoted}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ParticipationStatusBadge(hasVoted: hasVoted),
        ),
      ),
    );
  }

  testWidgets('indica quando o usuário já votou', (tester) async {
    await pumpBadge(tester, hasVoted: true);

    expect(find.text('Já votou'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('Pendente'), findsNothing);
  });

  testWidgets('indica quando a participação está pendente', (tester) async {
    await pumpBadge(tester, hasVoted: false);

    expect(find.text('Pendente'), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    expect(find.text('Já votou'), findsNothing);
  });
}

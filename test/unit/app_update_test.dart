import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/core/update/app_update.dart';

void main() {
  const store = 'https://play.google.com/store/apps/details?id=br.com.patotasapp';

  test('abaixo da mínima bloqueia', () {
    final info = evaluateAppUpdate(
        5, {'minBuild': 6, 'latestBuild': 9, 'storeUrl': store});
    expect(info.status, AppUpdateStatus.required);
    expect(info.storeUrl, store);
  });

  test('entre a mínima e a mais recente só avisa', () {
    final info = evaluateAppUpdate(7, {'minBuild': 6, 'latestBuild': 9});
    expect(info.status, AppUpdateStatus.optional);
  });

  test('na mais recente ou sem configuração fica em dia', () {
    expect(evaluateAppUpdate(9, {'minBuild': 6, 'latestBuild': 9}).status,
        AppUpdateStatus.upToDate);
    expect(evaluateAppUpdate(1, {}).status, AppUpdateStatus.upToDate);
  });

  testWidgets('tela de atualização obrigatória mostra o botão da loja',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: AppUpdateRequiredScreen(storeUrl: store)));
    expect(find.text('Atualize o PatotasApp'), findsOneWidget);
    expect(find.text('Atualizar agora'), findsOneWidget);
  });
}

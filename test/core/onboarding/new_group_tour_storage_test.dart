import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/core/onboarding/new_group_tour_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('persiste a etapa e restaura apenas para criador e patota corretos',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final storage = NewGroupTourStorage(preferences);

    await storage.start(creatorUserId: 'user-1', groupId: 'group-1');
    await storage.updateSettingsTab(3);

    final restored = storage.readFor(userId: 'user-1', groupId: 'group-1');
    expect(restored?.stage, NewGroupTourStage.settings);
    expect(restored?.settingsTab, 3);
    expect(restored?.location, '/app/settings?tour=true&tab=3');
    expect(storage.readForCreator('user-1')?.groupId, 'group-1');
    expect(storage.readForCreator('user-2'), isNull);
    expect(storage.readFor(userId: 'user-2', groupId: 'group-1'), isNull);
    expect(storage.readFor(userId: 'user-1', groupId: 'group-2'), isNull);
  });

  test('mantém o tour até concluir ou pular', () async {
    final preferences = await SharedPreferences.getInstance();
    final storage = NewGroupTourStorage(preferences);

    await storage.start(creatorUserId: 'user-1', groupId: 'group-1');
    await storage.moveTo(NewGroupTourStage.uniforms);
    expect(storage.read()?.location, '/app/team-colors?tour=true');

    await storage.moveTo(NewGroupTourStage.firstMatch);
    expect(storage.read()?.location, '/app/matches?tour=true');

    await storage.clear();
    expect(storage.read(), isNull);
  });
}

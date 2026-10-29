import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/championships/presentation/widgets/championship_draw_panel.dart';
import 'package:patotas_app/features/team_colors/domain/entities/team_color.dart';

void main() {
  const colors = [
    TeamColor(id: 'azul', name: 'Azul', hexValue: '#0000FF', isActive: true),
    TeamColor(id: 'verde', name: 'Verde', hexValue: '#00FF00', isActive: true),
    TeamColor(id: 'preto', name: 'Preto', hexValue: '#000000', isActive: true),
    TeamColor(id: 'rosa', name: 'Rosa', hexValue: '#FF00FF', isActive: false),
  ];

  List<String> ids(List<TeamColor> list) => [for (final c in list) c.id];

  test('não mostra as cores dos outros times; mostra a atual deste', () {
    final free = freeTeamColors(
      colors,
      current: 'verde',
      takenByOthers: {'azul', 'preto'},
    );
    expect(ids(free), ['verde']);
  });

  test('sem cor atual: só as ativas livres', () {
    expect(
      ids(freeTeamColors(colors, current: null, takenByOthers: {'azul'})),
      ['verde', 'preto'],
    );
  });

  test('a cor atual aparece mesmo se ficou inativa', () {
    expect(
      ids(freeTeamColors(colors, current: 'rosa', takenByOthers: const {})),
      ['azul', 'verde', 'preto', 'rosa'],
    );
  });
}

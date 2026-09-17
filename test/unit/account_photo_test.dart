import 'package:patotas_app/features/auth/domain/entities/account.dart';
import 'package:flutter_test/flutter_test.dart';

/// A foto do usuário logado alimenta o avatar da barra superior. Antes ela vinha de
/// MyPlayer, cuja lista é vazia para quem ainda não entrou em nenhuma patota — então
/// usuário novo ficava sem avatar mesmo tendo enviado a foto.
void main() {
  Account account({String? photoUrl}) => Account(
        userId: 'user-1',
        name: 'Andrei',
        email: 'andrei@example.com',
        roles: const ['User'],
        photoUrl: photoUrl,
      );

  test('a foto sobrevive ao round-trip de persistência', () {
    const url = 'https://pub-abc.r2.dev/avatars/u/foto.jpg';

    final restored = Account.fromJson(account(photoUrl: url).toJson());

    expect(restored.photoUrl, url);
  });

  test('conta sem foto persiste como nula', () {
    final restored = Account.fromJson(account().toJson());

    expect(restored.photoUrl, isNull);
  });

  test('copyWith troca a foto sem mexer no resto', () {
    final updated = account(photoUrl: 'antiga.jpg')
        .copyWith(photoUrl: 'https://pub-abc.r2.dev/avatars/u/nova.jpg');

    expect(updated.photoUrl, 'https://pub-abc.r2.dev/avatars/u/nova.jpg');
    expect(updated.userId, 'user-1');
    expect(updated.email, 'andrei@example.com');
  });

  /// copyWith não serve para REMOVER a foto: nele `null` significa "mantém o valor
  /// atual". Sem um setter explícito, excluir a foto deixaria o avatar antigo na barra.
  test('withPhoto limpa a foto quando recebe nulo', () {
    final cleared = account(photoUrl: 'https://pub-abc.r2.dev/avatars/u/foto.jpg')
        .withPhoto(null);

    expect(cleared.photoUrl, isNull);
    expect(cleared.userId, 'user-1');
  });

  test('withPhoto troca a foto quando recebe uma URL', () {
    final updated = account(photoUrl: 'antiga.jpg')
        .withPhoto('https://pub-abc.r2.dev/avatars/u/nova.jpg');

    expect(updated.photoUrl, 'https://pub-abc.r2.dev/avatars/u/nova.jpg');
  });

  /// Conta gravada por uma versão anterior do app não tem a chave photoUrl. Ela precisa
  /// abrir sem foto, não estourar na desserialização.
  test('conta persistida por versão antiga carrega sem a chave', () {
    final legacy = account().toJson()..remove('photoUrl');

    expect(Account.fromJson(legacy).photoUrl, isNull);
  });
}

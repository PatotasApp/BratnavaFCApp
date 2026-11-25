import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/discovery_datasource.dart';

/// A patota está aberta a jogadores de fora? Só então "Completar com
/// jogadores de fora" faz sentido: fora da busca ou sem aceitar jogadores,
/// ninguém acha a patota. Em caso de erro, assume aberta.
final groupOpenToOutsidersProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, groupId) async {
  try {
    final profile =
        await DiscoveryDataSource(ref.read(dioProvider)).group(groupId);
    return profile.isPublic && profile.accepting;
  } catch (_) {
    return true;
  }
});

/// Decide se o item "Interessados" aparece no menu Mais do admin.
///
/// Fica escondido quando a patota não recebe candidaturas (fora da busca ou
/// sem aceitar jogadores) e não há nenhuma candidatura ou convite no
/// histórico. Se existir algo, o item continua para o admin não perder
/// pendências nem histórico. Em caso de erro, mostra (nunca esconde às cegas).
final applicantsMenuVisibleProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, groupId) async {
  final api = DiscoveryDataSource(ref.read(dioProvider));
  try {
    final profile = await api.group(groupId);
    if (profile.isPublic && profile.accepting) return true;
    final applications = await api.applications(groupId);
    return applications.isNotEmpty;
  } catch (_) {
    return true;
  }
});

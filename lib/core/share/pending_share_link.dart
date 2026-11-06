import 'share_links.dart';

/// Guarda o link compartilhado (App Link/Universal Link) enquanto o app passa
/// pelo splash e pelo login. Sem isso o redirect do GoRouter mandaria para
/// /splash ou /login e, ao terminar, para /app — perdendo o link.
class PendingShareLink {
  String? _location;

  String? get location => _location;

  /// Guarda [uri] se for um link compartilhado; ignora qualquer outra rota.
  void remember(Uri uri) {
    if (ShareTarget.parse(uri) != null) _location = uri.path;
  }

  /// Devolve o link guardado (uma vez só) ou null.
  String? take() {
    final value = _location;
    _location = null;
    return value;
  }
}

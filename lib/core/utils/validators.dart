class Validators {
  Validators._();

  static String? required(String? v, [String label = 'Campo']) {
    if (v == null || v.trim().isEmpty) return '$label é obrigatório.';
    return null;
  }

  static String? minLength(String? v, int min, [String label = 'Campo']) {
    if (v == null || v.trim().length < min) {
      return '$label deve ter no mínimo $min caracteres.';
    }
    return null;
  }

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'E-mail é obrigatório.';
    final re = RegExp(r'^[\w.+\-]+@[\w\-]+\.[a-zA-Z]{2,}$');
    if (!re.hasMatch(v.trim())) return 'E-mail inválido.';
    return null;
  }

  /// Encadeia múltiplos validadores, retorna o primeiro erro.
  static String? chain(String? v, List<String? Function(String?)> validators) {
    for (final fn in validators) {
      final err = fn(v);
      if (err != null) return err;
    }
    return null;
  }
}

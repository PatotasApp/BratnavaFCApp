/// Desempacota a resposta da API que usa o envelope
/// { success, data, message, error, errors }.
///
/// Se a resposta já for uma lista direta, retorna ela mesma.
List<dynamic> unwrapList(dynamic raw) {
  if (raw is List) return raw;
  if (raw is Map) {
    final data = raw['data'] ?? raw['Data'];
    if (data is List) return data;
    if (data is Map) {
      final items = data['items'] ?? data['Items'];
      if (items is List) return items;
    }
    final items = raw['items'] ?? raw['Items'];
    if (items is List) return items;
  }
  return [];
}

/// Desempacota um objeto (Map) do envelope.
Map<String, dynamic>? unwrapMap(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    final data = raw['data'] ?? raw['Data'];
    if (data is Map<String, dynamic>) return data;
    return raw; // sem envelope, já é o objeto
  }
  return null;
}

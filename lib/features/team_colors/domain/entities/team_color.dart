import 'package:flutter/material.dart';

class TeamColor {
  final String id;
  final String name;
  final String hexValue; // always includes '#'
  final bool isActive;

  const TeamColor({
    required this.id,
    required this.name,
    required this.hexValue,
    required this.isActive,
  });

  Color get color => _parseHex(hexValue) ?? const Color(0xFFe2e8f0);

  factory TeamColor.fromJson(Map<String, dynamic> j) => TeamColor(
        id: j['id'] as String,
        name: j['name'] as String,
        hexValue: _normalizeHex(j['hexValue'] as String? ?? ''),
        isActive: (j['isActive'] as bool?) ?? false,
      );

  static String _normalizeHex(String v) {
    final s = v.trim();
    if (s.isEmpty) return '#e2e8f0';
    return s.startsWith('#') ? s : '#$s';
  }

  static Color? _parseHex(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      if (h.length == 3) {
        final r = h[0] + h[0];
        final g = h[1] + h[1];
        final b = h[2] + h[2];
        return Color(int.parse('FF$r$g$b', radix: 16));
      }
      if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    } catch (_) {}
    return null;
  }
}

import 'package:equatable/equatable.dart';
import '../../../../core/utils/date_utils.dart';

class AppUser extends Equatable {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String userName;
  final List<String> roles;
  final bool isActive;

  // Optional profile fields (returned by GET /api/Users/{id})
  final String? phone;
  final String? birthDate;
  final String? createdAt;
  final String? updatedAt;
  final String? inactivatedAt;

  const AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.userName,
    required this.roles,
    required this.isActive,
    this.phone,
    this.birthDate,
    this.createdAt,
    this.updatedAt,
    this.inactivatedAt,
  });

  String get fullName {
    final full = '$firstName $lastName'.trim();
    return full.isNotEmpty ? full : (userName.isNotEmpty ? userName : email);
  }

  bool get isAdmin => roles.any((r) => r.toLowerCase() == 'admin');

  /// Maps integer `role` field → readable label.
  static List<String> _rolesFromJson(Map<String, dynamic> j) {
    if (j['roles'] is List) {
      return List<String>.from((j['roles'] as List).map((e) => e.toString()));
    }
    final roleInt = j['role'] as int?;
    return switch (roleInt) {
      3 => ['Admin'],
      2 => ['Financeiro'],
      _ => ['Membro'],
    };
  }

  /// Formats an ISO date string to dd/MM/yyyy, or returns null.
  static String? _fmtDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.isEmpty) return null;
    try {
      final d = AppDateUtils.parseOrNow(s);
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';
    } catch (_) {
      return s;
    }
  }

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String? ?? j['userId'] as String? ?? '',
        firstName: j['firstName'] as String? ?? '',
        lastName: j['lastName'] as String? ?? '',
        email: j['email'] as String? ?? '',
        userName: j['userName'] as String? ?? j['username'] as String? ?? '',
        roles: _rolesFromJson(j),
        isActive: j['isActive'] as bool? ??
            (j['status'] is int ? (j['status'] as int) == 1 : null) ??
            true,
        phone: j['phone'] as String?,
        birthDate: _fmtDate(j['birthDate'] ?? j['dateOfBirth']),
        createdAt: _fmtDate(j['createdAt'] ?? j['createdDate']),
        updatedAt: _fmtDate(j['updatedAt'] ?? j['updatedDate']),
        inactivatedAt: _fmtDate(j['inactivatedAt']),
      );

  @override
  List<Object?> get props => [
        id,
        firstName,
        lastName,
        email,
        userName,
        roles,
        isActive,
        phone,
        birthDate,
        createdAt,
        updatedAt,
        inactivatedAt,
      ];
}

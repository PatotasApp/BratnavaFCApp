class BirthdayStatus {
  final String playerId;
  final String name;
  final bool hasBirthday;
  final String? birthDate; // "dd/MM/yyyy" from API
  final int? birthMonth;
  final int? birthDay;
  final bool isGoalkeeper;

  const BirthdayStatus({
    required this.playerId,
    required this.name,
    required this.hasBirthday,
    this.birthDate,
    this.birthMonth,
    this.birthDay,
    this.isGoalkeeper = false,
  });

  factory BirthdayStatus.fromJson(Map<String, dynamic> j) => BirthdayStatus(
        playerId: (j['playerId'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        hasBirthday: (j['hasBirthday'] as bool?) ?? false,
        birthDate: j['birthDate'] as String?,
        birthMonth: j['birthMonth'] as int?,
        birthDay: j['birthDay'] as int?,
        isGoalkeeper: (j['isGoalkeeper'] ?? false) as bool? ?? false,
      );
}

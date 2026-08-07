import 'package:equatable/equatable.dart';
import '../../../../core/utils/date_utils.dart';

// ── CalendarEvent ──────────────────────────────────────────────────────────────

class CalendarEvent extends Equatable {
  final String? id;
  final String type; // 'manual' | 'birthday' | 'match' | 'holiday' | 'event'
  final String title;
  final String date; // "YYYY-MM-DD"
  final String? time;
  final bool timeTBD;
  final String? categoryId;
  final String? categoryName;
  final String? categoryColor;
  final String? categoryIcon;
  final String? icon;
  final String? sourceId;
  final String? description;

  const CalendarEvent({
    this.id,
    required this.type,
    required this.title,
    required this.date,
    this.time,
    required this.timeTBD,
    this.categoryId,
    this.categoryName,
    this.categoryColor,
    this.categoryIcon,
    this.icon,
    this.sourceId,
    this.description,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> j) => CalendarEvent(
        id: j['id'] as String?,
        type: j['type'] as String? ?? 'manual',
        title: j['title'] as String? ?? '',
        date: j['date'] as String? ?? '',
        time: j['time'] as String?,
        timeTBD: j['timeTBD'] as bool? ?? false,
        categoryId: j['categoryId'] as String?,
        categoryName: j['categoryName'] as String?,
        categoryColor: j['categoryColor'] as String?,
        categoryIcon: j['categoryIcon'] as String?,
        icon: j['icon'] as String?,
        sourceId: j['sourceId'] as String?,
        description: j['description'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'type': type,
        'title': title,
        'date': date,
        if (time != null) 'time': time,
        'timeTBD': timeTBD,
        if (categoryId != null) 'categoryId': categoryId,
        if (description != null) 'description': description,
        if (icon != null) 'icon': icon,
      };

  bool get isPast {
    try {
      return DateTime.now().isAfter(AppDateUtils.parseOrNow(date));
    } catch (_) {
      return false;
    }
  }

  @override
  List<Object?> get props => [id, type, title, date, time];
}

// ── CalendarCategory ──────────────────────────────────────────────────────────

class CalendarCategory extends Equatable {
  final String id;
  final String name;
  final String? color;
  final String? icon;
  final bool isSystem;

  const CalendarCategory({
    required this.id,
    required this.name,
    this.color,
    this.icon,
    required this.isSystem,
  });

  factory CalendarCategory.fromJson(Map<String, dynamic> j) => CalendarCategory(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        color: j['color'] as String?,
        icon: j['icon'] as String?,
        isSystem: j['isSystem'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (color != null) 'color': color,
        if (icon != null) 'icon': icon,
      };

  @override
  List<Object?> get props => [id, name, color, icon];
}

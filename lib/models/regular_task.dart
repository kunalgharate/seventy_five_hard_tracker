import 'package:hive/hive.dart';
import 'package:equatable/equatable.dart';
import 'challenge.dart';

part 'regular_task.g.dart';

@HiveType(typeId: 3)
class RegularTask extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String? reminderTime; // Format: "HH:mm"

  @HiveField(3)
  final bool isReminderEnabled;

  @HiveField(4)
  final String? imagePath;

  @HiveField(5)
  final String? iconName;

  @HiveField(6)
  final int? iconColor;

  @HiveField(7)
  final String category;

  @HiveField(8)
  final String reminderType; // 'once', 'hourly', 'custom'

  @HiveField(9)
  final int reminderStartHour;

  @HiveField(10)
  final int reminderEndHour;

  @HiveField(11)
  final bool allowNightReminders;

  @HiveField(12)
  final int? reminderIntervalMinutes;

  @HiveField(13)
  final DateTime createdAt;

  @HiveField(14)
  final bool isArchived;

  const RegularTask({
    required this.id,
    required this.title,
    this.reminderTime,
    this.isReminderEnabled = false,
    this.imagePath,
    this.iconName,
    this.iconColor,
    this.category = 'general',
    this.reminderType = 'once',
    this.reminderStartHour = 8,
    this.reminderEndHour = 22,
    this.allowNightReminders = true,
    this.reminderIntervalMinutes,
    required this.createdAt,
    this.isArchived = false,
  });

  RegularTask copyWith({
    String? id,
    String? title,
    String? reminderTime,
    bool? isReminderEnabled,
    String? imagePath,
    String? iconName,
    int? iconColor,
    String? category,
    String? reminderType,
    int? reminderStartHour,
    int? reminderEndHour,
    bool? allowNightReminders,
    int? reminderIntervalMinutes,
    DateTime? createdAt,
    bool? isArchived,
  }) {
    return RegularTask(
      id: id ?? this.id,
      title: title ?? this.title,
      reminderTime: reminderTime ?? this.reminderTime,
      isReminderEnabled: isReminderEnabled ?? this.isReminderEnabled,
      imagePath: imagePath ?? this.imagePath,
      iconName: iconName ?? this.iconName,
      iconColor: iconColor ?? this.iconColor,
      category: category ?? this.category,
      reminderType: reminderType ?? this.reminderType,
      reminderStartHour: reminderStartHour ?? this.reminderStartHour,
      reminderEndHour: reminderEndHour ?? this.reminderEndHour,
      allowNightReminders: allowNightReminders ?? this.allowNightReminders,
      reminderIntervalMinutes:
          reminderIntervalMinutes ?? this.reminderIntervalMinutes,
      createdAt: createdAt ?? this.createdAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'reminderTime': reminderTime,
        'isReminderEnabled': isReminderEnabled,
        'imagePath': imagePath,
        'iconName': iconName,
        'iconColor': iconColor,
        'category': category,
        'reminderType': reminderType,
        'reminderStartHour': reminderStartHour,
        'reminderEndHour': reminderEndHour,
        'allowNightReminders': allowNightReminders,
        'reminderIntervalMinutes': reminderIntervalMinutes,
        'createdAt': createdAt.toIso8601String(),
        'isArchived': isArchived,
      };

  factory RegularTask.fromJson(Map<String, dynamic> json) {
    return RegularTask(
      id: json['id'] as String,
      title: json['title'] as String,
      reminderTime: json['reminderTime'] as String?,
      isReminderEnabled: json['isReminderEnabled'] as bool? ?? false,
      imagePath: json['imagePath'] as String?,
      iconName: json['iconName'] as String?,
      iconColor: json['iconColor'] as int?,
      category: json['category'] as String? ?? 'general',
      reminderType: json['reminderType'] as String? ?? 'once',
      reminderStartHour: json['reminderStartHour'] as int? ?? 8,
      reminderEndHour: json['reminderEndHour'] as int? ?? 22,
      allowNightReminders: json['allowNightReminders'] as bool? ?? true,
      reminderIntervalMinutes: json['reminderIntervalMinutes'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isArchived: json['isArchived'] as bool? ?? false,
    );
  }

  /// Adapter method to convert RegularTask to a Challenge object
  /// for reuse with the DailyTaskCard widget.
  Challenge toChallenge() {
    return Challenge(
      id: id,
      title: title,
      reminderTime: reminderTime,
      isReminderEnabled: isReminderEnabled,
      imagePath: imagePath,
      iconName: iconName,
      iconColor: iconColor,
      category: category,
      taskType: 'regular',
      reminderType: reminderType,
      reminderStartHour: reminderStartHour,
      reminderEndHour: reminderEndHour,
      allowNightReminders: allowNightReminders,
      reminderIntervalMinutes: reminderIntervalMinutes,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        reminderTime,
        isReminderEnabled,
        imagePath,
        iconName,
        iconColor,
        category,
        reminderType,
        reminderStartHour,
        reminderEndHour,
        allowNightReminders,
        reminderIntervalMinutes,
        createdAt,
        isArchived,
      ];
}

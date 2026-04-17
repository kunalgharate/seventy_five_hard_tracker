import 'package:hive/hive.dart';
import 'package:equatable/equatable.dart';

part 'challenge.g.dart';

enum TaskType {
  hard, // Must complete - resets to day 1 if missed
  soft, // Should complete - doesn't reset but tracked
  regular // Optional - for habit tracking only
}

enum ReminderType {
  once, // Single reminder at specific time
  hourly, // Hourly reminders within time window
  custom // Custom interval
}

@HiveType(typeId: 0)
class Challenge extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String? reminderTime; // Format: "HH:mm"

  @HiveField(3)
  final bool isReminderEnabled;

  @HiveField(4)
  final String? imagePath; // Path to custom image

  @HiveField(5)
  final String? iconName; // Name of predefined icon

  @HiveField(6)
  final int? iconColor; // Color value for icon

  @HiveField(7)
  final String category; // Category for default icon selection

  @HiveField(8)
  final String taskType; // 'hard', 'soft', 'regular'

  @HiveField(9)
  final String reminderType; // 'once', 'hourly', 'custom'

  @HiveField(10)
  final int reminderStartHour; // Start hour for reminders (0-23)

  @HiveField(11)
  final int reminderEndHour; // End hour for reminders (0-23)

  @HiveField(12)
  final bool allowNightReminders; // Allow reminders 10pm-11:45pm

  @HiveField(13)
  final int? reminderIntervalMinutes; // For custom reminders

  @HiveField(14)
  final bool photoRequired; // Require photo proof

  @HiveField(15)
  final bool showInRegularTab; // Show in regular tasks tab

  const Challenge({
    required this.id,
    required this.title,
    this.reminderTime,
    this.isReminderEnabled = false,
    this.imagePath,
    this.iconName,
    this.iconColor,
    this.category = 'general',
    this.taskType = 'hard',
    this.reminderType = 'once',
    this.reminderStartHour = 8,
    this.reminderEndHour = 22,
    this.allowNightReminders = true,
    this.reminderIntervalMinutes,
    this.photoRequired = false,
    this.showInRegularTab = false,
  });

  TaskType get type {
    switch (taskType) {
      case 'soft':
        return TaskType.soft;
      case 'regular':
        return TaskType.regular;
      default:
        return TaskType.hard;
    }
  }

  ReminderType get reminder {
    switch (reminderType) {
      case 'hourly':
        return ReminderType.hourly;
      case 'custom':
        return ReminderType.custom;
      default:
        return ReminderType.once;
    }
  }

  Challenge copyWith({
    String? id,
    String? title,
    String? reminderTime,
    bool? isReminderEnabled,
    String? imagePath,
    String? iconName,
    int? iconColor,
    String? category,
    String? taskType,
    String? reminderType,
    int? reminderStartHour,
    int? reminderEndHour,
    bool? allowNightReminders,
    int? reminderIntervalMinutes,
    bool? photoRequired,
    bool? showInRegularTab,
  }) {
    return Challenge(
      id: id ?? this.id,
      title: title ?? this.title,
      reminderTime: reminderTime ?? this.reminderTime,
      isReminderEnabled: isReminderEnabled ?? this.isReminderEnabled,
      imagePath: imagePath ?? this.imagePath,
      iconName: iconName ?? this.iconName,
      iconColor: iconColor ?? this.iconColor,
      category: category ?? this.category,
      taskType: taskType ?? this.taskType,
      reminderType: reminderType ?? this.reminderType,
      reminderStartHour: reminderStartHour ?? this.reminderStartHour,
      reminderEndHour: reminderEndHour ?? this.reminderEndHour,
      allowNightReminders: allowNightReminders ?? this.allowNightReminders,
      reminderIntervalMinutes:
          reminderIntervalMinutes ?? this.reminderIntervalMinutes,
      photoRequired: photoRequired ?? this.photoRequired,
      showInRegularTab: showInRegularTab ?? this.showInRegularTab,
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
        'taskType': taskType,
        'reminderType': reminderType,
        'reminderStartHour': reminderStartHour,
        'reminderEndHour': reminderEndHour,
        'allowNightReminders': allowNightReminders,
        'reminderIntervalMinutes': reminderIntervalMinutes,
        'photoRequired': photoRequired,
        'showInRegularTab': showInRegularTab,
      };

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] as String,
      title: json['title'] as String,
      reminderTime: json['reminderTime'] as String?,
      isReminderEnabled: json['isReminderEnabled'] as bool? ?? false,
      imagePath: json['imagePath'] as String?,
      iconName: json['iconName'] as String?,
      iconColor: json['iconColor'] as int?,
      category: json['category'] as String? ?? 'general',
      taskType: json['taskType'] as String? ?? 'hard',
      reminderType: json['reminderType'] as String? ?? 'once',
      reminderStartHour: json['reminderStartHour'] as int? ?? 8,
      reminderEndHour: json['reminderEndHour'] as int? ?? 22,
      allowNightReminders: json['allowNightReminders'] as bool? ?? true,
      reminderIntervalMinutes: json['reminderIntervalMinutes'] as int?,
      photoRequired: json['photoRequired'] as bool? ?? false,
      showInRegularTab: json['showInRegularTab'] as bool? ?? false,
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
        taskType,
        reminderType,
        reminderStartHour,
        reminderEndHour,
        allowNightReminders,
        reminderIntervalMinutes,
        photoRequired,
        showInRegularTab
      ];
}

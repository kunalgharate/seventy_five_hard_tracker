import 'package:hive/hive.dart';
import 'package:equatable/equatable.dart';

part 'challenge.g.dart';

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

  const Challenge({
    required this.id,
    required this.title,
    this.reminderTime,
    this.isReminderEnabled = false,
    this.imagePath,
    this.iconName,
    this.iconColor,
    this.category = 'general',
  });

  Challenge copyWith({
    String? id,
    String? title,
    String? reminderTime,
    bool? isReminderEnabled,
    String? imagePath,
    String? iconName,
    int? iconColor,
    String? category,
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
    category
  ];
}

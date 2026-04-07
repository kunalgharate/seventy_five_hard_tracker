// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'challenge.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChallengeAdapter extends TypeAdapter<Challenge> {
  @override
  final int typeId = 0;

  @override
  Challenge read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Challenge(
      id: fields[0] as String,
      title: fields[1] as String,
      reminderTime: fields[2] as String?,
      isReminderEnabled: fields[3] as bool,
      imagePath: fields[4] as String?,
      iconName: fields[5] as String?,
      iconColor: fields[6] as int?,
      category: fields[7] as String,
      taskType: fields[8] as String,
      reminderType: fields[9] as String,
      reminderStartHour: fields[10] as int,
      reminderEndHour: fields[11] as int,
      allowNightReminders: fields[12] as bool,
      reminderIntervalMinutes: fields[13] as int?,
      photoRequired: fields[14] as bool,
      showInRegularTab: fields[15] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Challenge obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.reminderTime)
      ..writeByte(3)
      ..write(obj.isReminderEnabled)
      ..writeByte(4)
      ..write(obj.imagePath)
      ..writeByte(5)
      ..write(obj.iconName)
      ..writeByte(6)
      ..write(obj.iconColor)
      ..writeByte(7)
      ..write(obj.category)
      ..writeByte(8)
      ..write(obj.taskType)
      ..writeByte(9)
      ..write(obj.reminderType)
      ..writeByte(10)
      ..write(obj.reminderStartHour)
      ..writeByte(11)
      ..write(obj.reminderEndHour)
      ..writeByte(12)
      ..write(obj.allowNightReminders)
      ..writeByte(13)
      ..write(obj.reminderIntervalMinutes)
      ..writeByte(14)
      ..write(obj.photoRequired)
      ..writeByte(15)
      ..write(obj.showInRegularTab);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChallengeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

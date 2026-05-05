// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'regular_task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RegularTaskAdapter extends TypeAdapter<RegularTask> {
  @override
  final int typeId = 3;

  @override
  RegularTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RegularTask(
      id: fields[0] as String,
      title: fields[1] as String,
      reminderTime: fields[2] as String?,
      isReminderEnabled: fields[3] as bool,
      imagePath: fields[4] as String?,
      iconName: fields[5] as String?,
      iconColor: fields[6] as int?,
      category: fields[7] as String,
      reminderType: fields[8] as String,
      reminderStartHour: fields[9] as int,
      reminderEndHour: fields[10] as int,
      allowNightReminders: fields[11] as bool,
      reminderIntervalMinutes: fields[12] as int?,
      createdAt: fields[13] as DateTime,
      isArchived: fields[14] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, RegularTask obj) {
    writer
      ..writeByte(15)
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
      ..write(obj.reminderType)
      ..writeByte(9)
      ..write(obj.reminderStartHour)
      ..writeByte(10)
      ..write(obj.reminderEndHour)
      ..writeByte(11)
      ..write(obj.allowNightReminders)
      ..writeByte(12)
      ..write(obj.reminderIntervalMinutes)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.isArchived);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegularTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

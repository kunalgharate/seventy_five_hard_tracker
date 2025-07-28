// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_progress.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyProgressAdapter extends TypeAdapter<DailyProgress> {
  @override
  final int typeId = 1;

  @override
  DailyProgress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyProgress(
      date: fields[0] as DateTime,
      challengeCompletions: (fields[1] as Map).cast<String, bool>(),
      journalNote: fields[2] as String?,
      isCompleted: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, DailyProgress obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.challengeCompletions)
      ..writeByte(2)
      ..write(obj.journalNote)
      ..writeByte(3)
      ..write(obj.isCompleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyProgressAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

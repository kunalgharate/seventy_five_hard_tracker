// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'regular_task_completion.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RegularTaskCompletionAdapter extends TypeAdapter<RegularTaskCompletion> {
  @override
  final int typeId = 4;

  @override
  RegularTaskCompletion read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RegularTaskCompletion(
      date: fields[0] as DateTime,
      taskCompletions: (fields[1] as Map).cast<String, bool>(),
    );
  }

  @override
  void write(BinaryWriter writer, RegularTaskCompletion obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.taskCompletions);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegularTaskCompletionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

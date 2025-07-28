// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'challenge_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChallengeSessionAdapter extends TypeAdapter<ChallengeSession> {
  @override
  final int typeId = 2;

  @override
  ChallengeSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChallengeSession(
      id: fields[0] as String,
      challenges: (fields[1] as List).cast<Challenge>(),
      startDate: fields[2] as DateTime,
      endDate: fields[3] as DateTime?,
      isActive: fields[4] as bool,
      isCompleted: fields[5] as bool,
      currentDay: fields[6] as int,
      failureReason: fields[7] as String?,
      failedChallenges: (fields[8] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, ChallengeSession obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.challenges)
      ..writeByte(2)
      ..write(obj.startDate)
      ..writeByte(3)
      ..write(obj.endDate)
      ..writeByte(4)
      ..write(obj.isActive)
      ..writeByte(5)
      ..write(obj.isCompleted)
      ..writeByte(6)
      ..write(obj.currentDay)
      ..writeByte(7)
      ..write(obj.failureReason)
      ..writeByte(8)
      ..write(obj.failedChallenges);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChallengeSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

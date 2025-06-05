part of 'user.dart';

class UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = 0;

  @override
  User read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    try {
      final dynamic rawBalance = fields[3];
      final double balance = rawBalance is num
          ? rawBalance.toDouble()
          : double.tryParse(rawBalance.toString()) ?? 0.0;

      return User(
        username: fields[0] as String? ?? '',
        email: fields[2] as String? ?? '',
        hashedPassword: fields[1] as String? ?? '',
        dolarBalance: balance,
        purchaseHistory: (fields[4] as List?)?.cast<PurchaseHistory>() ?? [],
        profilePicPath: fields[5] as String? ?? 'assets/default_avatar.png',
        powerUpStats: fields[6] as PowerUpStats?,
      );
    } catch (e) {
      debugPrint('Error reading user data: $e');
      return User(
        username: '',
        email: '',
        hashedPassword: '',
        dolarBalance: 0.0,
      );
    }
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.username)
      ..writeByte(1)
      ..write(obj.hashedPassword)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.dolarBalance)
      ..writeByte(4)
      ..write(obj.purchaseHistory)
      ..writeByte(5)
      ..write(obj.profilePicPath)
      ..writeByte(6)
      ..write(obj.powerUpStats);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PurchaseHistoryAdapter extends TypeAdapter<PurchaseHistory> {
  @override
  final int typeId = 2;

  @override
  PurchaseHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PurchaseHistory(
      type: fields[0] as String,
      amount: fields[1] as double,
      price: fields[2] as String?,
      date: fields[3] as DateTime,
      item: fields[4] as String?,
      originalCurrency: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PurchaseHistory obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.price)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.item)
      ..writeByte(5)
      ..write(obj.originalCurrency);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PowerUpStatsAdapter extends TypeAdapter<PowerUpStats> {
  @override
  final int typeId = 3;

  @override
  PowerUpStats read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PowerUpStats(
      fiftyFiftyUsed: fields[0] as int,
      callFriendUsed: fields[1] as int,
      audienceUsed: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, PowerUpStats obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.fiftyFiftyUsed)
      ..writeByte(1)
      ..write(obj.callFriendUsed)
      ..writeByte(2)
      ..write(obj.audienceUsed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PowerUpStatsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

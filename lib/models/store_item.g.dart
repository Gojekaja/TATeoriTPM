part of 'store_item.dart';

class StoreItemAdapter extends TypeAdapter<StoreItem> {
  @override
  final int typeId = 4;

  @override
  StoreItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StoreItem(
      id: fields[0] as String,
      name: fields[1] as String,
      dolarPrice: fields[2] as double,
      type: fields[3] as String,
      iconName: fields[4] as String?,
      maxQuantity: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, StoreItem obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.dolarPrice)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.iconName)
      ..writeByte(5)
      ..write(obj.maxQuantity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoreItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

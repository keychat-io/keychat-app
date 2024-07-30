// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetRoomCollection on Isar {
  IsarCollection<Room> get rooms => this.collection();
}

const RoomSchema = CollectionSchema(
  name: r'Room',
  id: -1093513927825131211,
  properties: {
    r'autoDeleteDays': PropertySchema(
      id: 0,
      name: r'autoDeleteDays',
      type: IsarType.long,
    ),
    r'avatar': PropertySchema(
      id: 1,
      name: r'avatar',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 2,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'curve25519PkHex': PropertySchema(
      id: 3,
      name: r'curve25519PkHex',
      type: IsarType.string,
    ),
    r'encryptMode': PropertySchema(
      id: 4,
      name: r'encryptMode',
      type: IsarType.int,
      enumMap: _RoomencryptModeEnumValueMap,
    ),
    r'groupRelay': PropertySchema(
      id: 5,
      name: r'groupRelay',
      type: IsarType.string,
    ),
    r'groupType': PropertySchema(
      id: 6,
      name: r'groupType',
      type: IsarType.int,
      enumMap: _RoomgroupTypeEnumValueMap,
    ),
    r'hashCode': PropertySchema(
      id: 7,
      name: r'hashCode',
      type: IsarType.long,
    ),
    r'identityId': PropertySchema(
      id: 8,
      name: r'identityId',
      type: IsarType.long,
    ),
    r'isMute': PropertySchema(
      id: 9,
      name: r'isMute',
      type: IsarType.bool,
    ),
    r'myIdPubkey': PropertySchema(
      id: 10,
      name: r'myIdPubkey',
      type: IsarType.string,
    ),
    r'name': PropertySchema(
      id: 11,
      name: r'name',
      type: IsarType.string,
    ),
    r'npub': PropertySchema(
      id: 12,
      name: r'npub',
      type: IsarType.string,
    ),
    r'onetimekey': PropertySchema(
      id: 13,
      name: r'onetimekey',
      type: IsarType.string,
    ),
    r'pin': PropertySchema(
      id: 14,
      name: r'pin',
      type: IsarType.bool,
    ),
    r'pinAt': PropertySchema(
      id: 15,
      name: r'pinAt',
      type: IsarType.dateTime,
    ),
    r'signalDecodeError': PropertySchema(
      id: 16,
      name: r'signalDecodeError',
      type: IsarType.bool,
    ),
    r'signalIdPubkey': PropertySchema(
      id: 17,
      name: r'signalIdPubkey',
      type: IsarType.string,
    ),
    r'status': PropertySchema(
      id: 18,
      name: r'status',
      type: IsarType.int,
      enumMap: _RoomstatusEnumValueMap,
    ),
    r'stringify': PropertySchema(
      id: 19,
      name: r'stringify',
      type: IsarType.bool,
    ),
    r'toMainPubkey': PropertySchema(
      id: 20,
      name: r'toMainPubkey',
      type: IsarType.string,
    ),
    r'type': PropertySchema(
      id: 21,
      name: r'type',
      type: IsarType.int,
      enumMap: _RoomtypeEnumValueMap,
    ),
    r'version': PropertySchema(
      id: 22,
      name: r'version',
      type: IsarType.long,
    )
  },
  estimateSize: _roomEstimateSize,
  serialize: _roomSerialize,
  deserialize: _roomDeserialize,
  deserializeProp: _roomDeserializeProp,
  idName: r'id',
  indexes: {
    r'toMainPubkey_identityId': IndexSchema(
      id: -2319064167920074411,
      name: r'toMainPubkey_identityId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'toMainPubkey',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'identityId',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {
    r'mykey': LinkSchema(
      id: 8662272809427054137,
      name: r'mykey',
      target: r'Mykey',
      single: true,
    ),
    r'members': LinkSchema(
      id: -7049341341102959745,
      name: r'members',
      target: r'RoomMember',
      single: false,
    )
  },
  embeddedSchemas: {},
  getId: _roomGetId,
  getLinks: _roomGetLinks,
  attach: _roomAttach,
  version: '3.1.0+1',
);

int _roomEstimateSize(
  Room object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.avatar;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.curve25519PkHex;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.groupRelay;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.myIdPubkey.length * 3;
  {
    final value = object.name;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.npub.length * 3;
  {
    final value = object.onetimekey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.signalIdPubkey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.toMainPubkey.length * 3;
  return bytesCount;
}

void _roomSerialize(
  Room object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.autoDeleteDays);
  writer.writeString(offsets[1], object.avatar);
  writer.writeDateTime(offsets[2], object.createdAt);
  writer.writeString(offsets[3], object.curve25519PkHex);
  writer.writeInt(offsets[4], object.encryptMode.index);
  writer.writeString(offsets[5], object.groupRelay);
  writer.writeInt(offsets[6], object.groupType.index);
  writer.writeLong(offsets[7], object.hashCode);
  writer.writeLong(offsets[8], object.identityId);
  writer.writeBool(offsets[9], object.isMute);
  writer.writeString(offsets[10], object.myIdPubkey);
  writer.writeString(offsets[11], object.name);
  writer.writeString(offsets[12], object.npub);
  writer.writeString(offsets[13], object.onetimekey);
  writer.writeBool(offsets[14], object.pin);
  writer.writeDateTime(offsets[15], object.pinAt);
  writer.writeBool(offsets[16], object.signalDecodeError);
  writer.writeString(offsets[17], object.signalIdPubkey);
  writer.writeInt(offsets[18], object.status.index);
  writer.writeBool(offsets[19], object.stringify);
  writer.writeString(offsets[20], object.toMainPubkey);
  writer.writeInt(offsets[21], object.type.index);
  writer.writeLong(offsets[22], object.version);
}

Room _roomDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Room(
    identityId: reader.readLong(offsets[8]),
    npub: reader.readString(offsets[12]),
    status: _RoomstatusValueEnumMap[reader.readIntOrNull(offsets[18])] ??
        RoomStatus.init,
    toMainPubkey: reader.readString(offsets[20]),
    type: _RoomtypeValueEnumMap[reader.readIntOrNull(offsets[21])] ??
        RoomType.common,
  );
  object.autoDeleteDays = reader.readLong(offsets[0]);
  object.avatar = reader.readStringOrNull(offsets[1]);
  object.createdAt = reader.readDateTime(offsets[2]);
  object.curve25519PkHex = reader.readStringOrNull(offsets[3]);
  object.encryptMode =
      _RoomencryptModeValueEnumMap[reader.readIntOrNull(offsets[4])] ??
          EncryptMode.nip04;
  object.groupRelay = reader.readStringOrNull(offsets[5]);
  object.groupType =
      _RoomgroupTypeValueEnumMap[reader.readIntOrNull(offsets[6])] ??
          GroupType.shareKey;
  object.id = id;
  object.isMute = reader.readBool(offsets[9]);
  object.name = reader.readStringOrNull(offsets[11]);
  object.onetimekey = reader.readStringOrNull(offsets[13]);
  object.pin = reader.readBool(offsets[14]);
  object.pinAt = reader.readDateTimeOrNull(offsets[15]);
  object.signalDecodeError = reader.readBool(offsets[16]);
  object.signalIdPubkey = reader.readStringOrNull(offsets[17]);
  object.version = reader.readLong(offsets[22]);
  return object;
}

P _roomDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readDateTime(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (_RoomencryptModeValueEnumMap[reader.readIntOrNull(offset)] ??
          EncryptMode.nip04) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (_RoomgroupTypeValueEnumMap[reader.readIntOrNull(offset)] ??
          GroupType.shareKey) as P;
    case 7:
      return (reader.readLong(offset)) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    case 9:
      return (reader.readBool(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readBool(offset)) as P;
    case 15:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 16:
      return (reader.readBool(offset)) as P;
    case 17:
      return (reader.readStringOrNull(offset)) as P;
    case 18:
      return (_RoomstatusValueEnumMap[reader.readIntOrNull(offset)] ??
          RoomStatus.init) as P;
    case 19:
      return (reader.readBoolOrNull(offset)) as P;
    case 20:
      return (reader.readString(offset)) as P;
    case 21:
      return (_RoomtypeValueEnumMap[reader.readIntOrNull(offset)] ??
          RoomType.common) as P;
    case 22:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _RoomencryptModeEnumValueMap = {
  'nip04': 0,
  'signal': 1,
};
const _RoomencryptModeValueEnumMap = {
  0: EncryptMode.nip04,
  1: EncryptMode.signal,
};
const _RoomgroupTypeEnumValueMap = {
  'shareKey': 0,
  'sendAll': 1,
};
const _RoomgroupTypeValueEnumMap = {
  0: GroupType.shareKey,
  1: GroupType.sendAll,
};
const _RoomstatusEnumValueMap = {
  'init': 0,
  'requesting': 1,
  'approving': 2,
  'approvingNoResponse': 3,
  'rejected': 4,
  'enabled': 5,
  'disabled': 6,
  'dissolved': 7,
  'removedFromGroup': 8,
  'groupUser': 9,
};
const _RoomstatusValueEnumMap = {
  0: RoomStatus.init,
  1: RoomStatus.requesting,
  2: RoomStatus.approving,
  3: RoomStatus.approvingNoResponse,
  4: RoomStatus.rejected,
  5: RoomStatus.enabled,
  6: RoomStatus.disabled,
  7: RoomStatus.dissolved,
  8: RoomStatus.removedFromGroup,
  9: RoomStatus.groupUser,
};
const _RoomtypeEnumValueMap = {
  'common': 0,
  'private': 1,
  'group': 2,
};
const _RoomtypeValueEnumMap = {
  0: RoomType.common,
  1: RoomType.private,
  2: RoomType.group,
};

Id _roomGetId(Room object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _roomGetLinks(Room object) {
  return [object.mykey, object.members];
}

void _roomAttach(IsarCollection<dynamic> col, Id id, Room object) {
  object.id = id;
  object.mykey.attach(col, col.isar.collection<Mykey>(), r'mykey', id);
  object.members.attach(col, col.isar.collection<RoomMember>(), r'members', id);
}

extension RoomByIndex on IsarCollection<Room> {
  Future<Room?> getByToMainPubkeyIdentityId(
      String toMainPubkey, int identityId) {
    return getByIndex(r'toMainPubkey_identityId', [toMainPubkey, identityId]);
  }

  Room? getByToMainPubkeyIdentityIdSync(String toMainPubkey, int identityId) {
    return getByIndexSync(
        r'toMainPubkey_identityId', [toMainPubkey, identityId]);
  }

  Future<bool> deleteByToMainPubkeyIdentityId(
      String toMainPubkey, int identityId) {
    return deleteByIndex(
        r'toMainPubkey_identityId', [toMainPubkey, identityId]);
  }

  bool deleteByToMainPubkeyIdentityIdSync(String toMainPubkey, int identityId) {
    return deleteByIndexSync(
        r'toMainPubkey_identityId', [toMainPubkey, identityId]);
  }

  Future<List<Room?>> getAllByToMainPubkeyIdentityId(
      List<String> toMainPubkeyValues, List<int> identityIdValues) {
    final len = toMainPubkeyValues.length;
    assert(identityIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([toMainPubkeyValues[i], identityIdValues[i]]);
    }

    return getAllByIndex(r'toMainPubkey_identityId', values);
  }

  List<Room?> getAllByToMainPubkeyIdentityIdSync(
      List<String> toMainPubkeyValues, List<int> identityIdValues) {
    final len = toMainPubkeyValues.length;
    assert(identityIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([toMainPubkeyValues[i], identityIdValues[i]]);
    }

    return getAllByIndexSync(r'toMainPubkey_identityId', values);
  }

  Future<int> deleteAllByToMainPubkeyIdentityId(
      List<String> toMainPubkeyValues, List<int> identityIdValues) {
    final len = toMainPubkeyValues.length;
    assert(identityIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([toMainPubkeyValues[i], identityIdValues[i]]);
    }

    return deleteAllByIndex(r'toMainPubkey_identityId', values);
  }

  int deleteAllByToMainPubkeyIdentityIdSync(
      List<String> toMainPubkeyValues, List<int> identityIdValues) {
    final len = toMainPubkeyValues.length;
    assert(identityIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([toMainPubkeyValues[i], identityIdValues[i]]);
    }

    return deleteAllByIndexSync(r'toMainPubkey_identityId', values);
  }

  Future<Id> putByToMainPubkeyIdentityId(Room object) {
    return putByIndex(r'toMainPubkey_identityId', object);
  }

  Id putByToMainPubkeyIdentityIdSync(Room object, {bool saveLinks = true}) {
    return putByIndexSync(r'toMainPubkey_identityId', object,
        saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByToMainPubkeyIdentityId(List<Room> objects) {
    return putAllByIndex(r'toMainPubkey_identityId', objects);
  }

  List<Id> putAllByToMainPubkeyIdentityIdSync(List<Room> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'toMainPubkey_identityId', objects,
        saveLinks: saveLinks);
  }
}

extension RoomQueryWhereSort on QueryBuilder<Room, Room, QWhere> {
  QueryBuilder<Room, Room, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension RoomQueryWhere on QueryBuilder<Room, Room, QWhereClause> {
  QueryBuilder<Room, Room, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<Room, Room, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Room, Room, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Room, Room, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterWhereClause> toMainPubkeyEqualToAnyIdentityId(
      String toMainPubkey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'toMainPubkey_identityId',
        value: [toMainPubkey],
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterWhereClause>
      toMainPubkeyNotEqualToAnyIdentityId(String toMainPubkey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'toMainPubkey_identityId',
              lower: [],
              upper: [toMainPubkey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'toMainPubkey_identityId',
              lower: [toMainPubkey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'toMainPubkey_identityId',
              lower: [toMainPubkey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'toMainPubkey_identityId',
              lower: [],
              upper: [toMainPubkey],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<Room, Room, QAfterWhereClause> toMainPubkeyIdentityIdEqualTo(
      String toMainPubkey, int identityId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'toMainPubkey_identityId',
        value: [toMainPubkey, identityId],
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterWhereClause>
      toMainPubkeyEqualToIdentityIdNotEqualTo(
          String toMainPubkey, int identityId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'toMainPubkey_identityId',
              lower: [toMainPubkey],
              upper: [toMainPubkey, identityId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'toMainPubkey_identityId',
              lower: [toMainPubkey, identityId],
              includeLower: false,
              upper: [toMainPubkey],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'toMainPubkey_identityId',
              lower: [toMainPubkey, identityId],
              includeLower: false,
              upper: [toMainPubkey],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'toMainPubkey_identityId',
              lower: [toMainPubkey],
              upper: [toMainPubkey, identityId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<Room, Room, QAfterWhereClause>
      toMainPubkeyEqualToIdentityIdGreaterThan(
    String toMainPubkey,
    int identityId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'toMainPubkey_identityId',
        lower: [toMainPubkey, identityId],
        includeLower: include,
        upper: [toMainPubkey],
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterWhereClause>
      toMainPubkeyEqualToIdentityIdLessThan(
    String toMainPubkey,
    int identityId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'toMainPubkey_identityId',
        lower: [toMainPubkey],
        upper: [toMainPubkey, identityId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterWhereClause>
      toMainPubkeyEqualToIdentityIdBetween(
    String toMainPubkey,
    int lowerIdentityId,
    int upperIdentityId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'toMainPubkey_identityId',
        lower: [toMainPubkey, lowerIdentityId],
        includeLower: includeLower,
        upper: [toMainPubkey, upperIdentityId],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension RoomQueryFilter on QueryBuilder<Room, Room, QFilterCondition> {
  QueryBuilder<Room, Room, QAfterFilterCondition> autoDeleteDaysEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'autoDeleteDays',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> autoDeleteDaysGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'autoDeleteDays',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> autoDeleteDaysLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'autoDeleteDays',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> autoDeleteDaysBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'autoDeleteDays',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> avatarIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'avatar',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> avatarIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'avatar',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> avatarEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'avatar',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> avatarGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'avatar',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> avatarLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'avatar',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> avatarBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'avatar',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> avatarStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'avatar',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> avatarEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'avatar',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> avatarContains(String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'avatar',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> avatarMatches(String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'avatar',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> avatarIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'avatar',
        value: '',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> avatarIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'avatar',
        value: '',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> createdAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> curve25519PkHexIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'curve25519PkHex',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> curve25519PkHexIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'curve25519PkHex',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> curve25519PkHexEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'curve25519PkHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> curve25519PkHexGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'curve25519PkHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> curve25519PkHexLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'curve25519PkHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> curve25519PkHexBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'curve25519PkHex',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> curve25519PkHexStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'curve25519PkHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> curve25519PkHexEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'curve25519PkHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> curve25519PkHexContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'curve25519PkHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> curve25519PkHexMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'curve25519PkHex',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> curve25519PkHexIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'curve25519PkHex',
        value: '',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> curve25519PkHexIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'curve25519PkHex',
        value: '',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> encryptModeEqualTo(
      EncryptMode value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'encryptMode',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> encryptModeGreaterThan(
    EncryptMode value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'encryptMode',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> encryptModeLessThan(
    EncryptMode value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'encryptMode',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> encryptModeBetween(
    EncryptMode lower,
    EncryptMode upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'encryptMode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> groupRelayIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'groupRelay',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> groupRelayIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'groupRelay',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> groupRelayEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'groupRelay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> groupRelayGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'groupRelay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> groupRelayLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'groupRelay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> groupRelayBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'groupRelay',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> groupRelayStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'groupRelay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> groupRelayEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'groupRelay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> groupRelayContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'groupRelay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> groupRelayMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'groupRelay',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> groupRelayIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'groupRelay',
        value: '',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> groupRelayIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'groupRelay',
        value: '',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> groupTypeEqualTo(
      GroupType value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'groupType',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> groupTypeGreaterThan(
    GroupType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'groupType',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> groupTypeLessThan(
    GroupType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'groupType',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> groupTypeBetween(
    GroupType lower,
    GroupType upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'groupType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> hashCodeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hashCode',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> hashCodeGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'hashCode',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> hashCodeLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'hashCode',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> hashCodeBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'hashCode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> identityIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'identityId',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> identityIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'identityId',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> identityIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'identityId',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> identityIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'identityId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> isMuteEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isMute',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> myIdPubkeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'myIdPubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> myIdPubkeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'myIdPubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> myIdPubkeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'myIdPubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> myIdPubkeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'myIdPubkey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> myIdPubkeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'myIdPubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> myIdPubkeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'myIdPubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> myIdPubkeyContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'myIdPubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> myIdPubkeyMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'myIdPubkey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> myIdPubkeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'myIdPubkey',
        value: '',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> myIdPubkeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'myIdPubkey',
        value: '',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> nameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'name',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> nameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'name',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> nameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> nameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> nameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> nameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'name',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> nameContains(String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> nameMatches(String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'name',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> npubEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'npub',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> npubGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'npub',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> npubLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'npub',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> npubBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'npub',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> npubStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'npub',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> npubEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'npub',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> npubContains(String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'npub',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> npubMatches(String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'npub',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> npubIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'npub',
        value: '',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> npubIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'npub',
        value: '',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> onetimekeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'onetimekey',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> onetimekeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'onetimekey',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> onetimekeyEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'onetimekey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> onetimekeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'onetimekey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> onetimekeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'onetimekey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> onetimekeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'onetimekey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> onetimekeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'onetimekey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> onetimekeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'onetimekey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> onetimekeyContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'onetimekey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> onetimekeyMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'onetimekey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> onetimekeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'onetimekey',
        value: '',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> onetimekeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'onetimekey',
        value: '',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> pinEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pin',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> pinAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'pinAt',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> pinAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'pinAt',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> pinAtEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pinAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> pinAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'pinAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> pinAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'pinAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> pinAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'pinAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> signalDecodeErrorEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'signalDecodeError',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> signalIdPubkeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'signalIdPubkey',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> signalIdPubkeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'signalIdPubkey',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> signalIdPubkeyEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'signalIdPubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> signalIdPubkeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'signalIdPubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> signalIdPubkeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'signalIdPubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> signalIdPubkeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'signalIdPubkey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> signalIdPubkeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'signalIdPubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> signalIdPubkeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'signalIdPubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> signalIdPubkeyContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'signalIdPubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> signalIdPubkeyMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'signalIdPubkey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> signalIdPubkeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'signalIdPubkey',
        value: '',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> signalIdPubkeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'signalIdPubkey',
        value: '',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> statusEqualTo(
      RoomStatus value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> statusGreaterThan(
    RoomStatus value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'status',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> statusLessThan(
    RoomStatus value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'status',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> statusBetween(
    RoomStatus lower,
    RoomStatus upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'status',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> stringifyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'stringify',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> stringifyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'stringify',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> stringifyEqualTo(
      bool? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'stringify',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> toMainPubkeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'toMainPubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> toMainPubkeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'toMainPubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> toMainPubkeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'toMainPubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> toMainPubkeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'toMainPubkey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> toMainPubkeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'toMainPubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> toMainPubkeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'toMainPubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> toMainPubkeyContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'toMainPubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> toMainPubkeyMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'toMainPubkey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> toMainPubkeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'toMainPubkey',
        value: '',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> toMainPubkeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'toMainPubkey',
        value: '',
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> typeEqualTo(RoomType value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'type',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> typeGreaterThan(
    RoomType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'type',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> typeLessThan(
    RoomType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'type',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> typeBetween(
    RoomType lower,
    RoomType upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'type',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> versionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> versionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> versionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> versionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'version',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension RoomQueryObject on QueryBuilder<Room, Room, QFilterCondition> {}

extension RoomQueryLinks on QueryBuilder<Room, Room, QFilterCondition> {
  QueryBuilder<Room, Room, QAfterFilterCondition> mykey(FilterQuery<Mykey> q) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'mykey');
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> mykeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'mykey', 0, true, 0, true);
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> members(
      FilterQuery<RoomMember> q) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'members');
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> membersLengthEqualTo(
      int length) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'members', length, true, length, true);
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> membersIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'members', 0, true, 0, true);
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> membersIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'members', 0, false, 999999, true);
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> membersLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'members', 0, true, length, include);
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> membersLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'members', length, include, 999999, true);
    });
  }

  QueryBuilder<Room, Room, QAfterFilterCondition> membersLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(
          r'members', lower, includeLower, upper, includeUpper);
    });
  }
}

extension RoomQuerySortBy on QueryBuilder<Room, Room, QSortBy> {
  QueryBuilder<Room, Room, QAfterSortBy> sortByAutoDeleteDays() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoDeleteDays', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByAutoDeleteDaysDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoDeleteDays', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByAvatar() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avatar', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByAvatarDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avatar', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByCurve25519PkHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'curve25519PkHex', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByCurve25519PkHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'curve25519PkHex', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByEncryptMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'encryptMode', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByEncryptModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'encryptMode', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByGroupRelay() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupRelay', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByGroupRelayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupRelay', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByGroupType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupType', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByGroupTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupType', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByIdentityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identityId', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByIdentityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identityId', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByIsMute() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isMute', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByIsMuteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isMute', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByMyIdPubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'myIdPubkey', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByMyIdPubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'myIdPubkey', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByNpub() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'npub', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByNpubDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'npub', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByOnetimekey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'onetimekey', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByOnetimekeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'onetimekey', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByPin() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pin', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByPinDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pin', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByPinAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pinAt', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByPinAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pinAt', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortBySignalDecodeError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signalDecodeError', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortBySignalDecodeErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signalDecodeError', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortBySignalIdPubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signalIdPubkey', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortBySignalIdPubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signalIdPubkey', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByStringifyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByToMainPubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toMainPubkey', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByToMainPubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toMainPubkey', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension RoomQuerySortThenBy on QueryBuilder<Room, Room, QSortThenBy> {
  QueryBuilder<Room, Room, QAfterSortBy> thenByAutoDeleteDays() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoDeleteDays', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByAutoDeleteDaysDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoDeleteDays', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByAvatar() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avatar', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByAvatarDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avatar', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByCurve25519PkHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'curve25519PkHex', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByCurve25519PkHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'curve25519PkHex', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByEncryptMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'encryptMode', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByEncryptModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'encryptMode', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByGroupRelay() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupRelay', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByGroupRelayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupRelay', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByGroupType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupType', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByGroupTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupType', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByIdentityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identityId', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByIdentityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identityId', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByIsMute() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isMute', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByIsMuteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isMute', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByMyIdPubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'myIdPubkey', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByMyIdPubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'myIdPubkey', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByNpub() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'npub', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByNpubDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'npub', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByOnetimekey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'onetimekey', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByOnetimekeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'onetimekey', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByPin() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pin', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByPinDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pin', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByPinAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pinAt', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByPinAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pinAt', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenBySignalDecodeError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signalDecodeError', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenBySignalDecodeErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signalDecodeError', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenBySignalIdPubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signalIdPubkey', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenBySignalIdPubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signalIdPubkey', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByStringifyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByToMainPubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toMainPubkey', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByToMainPubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toMainPubkey', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<Room, Room, QAfterSortBy> thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension RoomQueryWhereDistinct on QueryBuilder<Room, Room, QDistinct> {
  QueryBuilder<Room, Room, QDistinct> distinctByAutoDeleteDays() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'autoDeleteDays');
    });
  }

  QueryBuilder<Room, Room, QDistinct> distinctByAvatar(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'avatar', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Room, Room, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<Room, Room, QDistinct> distinctByCurve25519PkHex(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'curve25519PkHex',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Room, Room, QDistinct> distinctByEncryptMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'encryptMode');
    });
  }

  QueryBuilder<Room, Room, QDistinct> distinctByGroupRelay(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'groupRelay', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Room, Room, QDistinct> distinctByGroupType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'groupType');
    });
  }

  QueryBuilder<Room, Room, QDistinct> distinctByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hashCode');
    });
  }

  QueryBuilder<Room, Room, QDistinct> distinctByIdentityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'identityId');
    });
  }

  QueryBuilder<Room, Room, QDistinct> distinctByIsMute() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isMute');
    });
  }

  QueryBuilder<Room, Room, QDistinct> distinctByMyIdPubkey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'myIdPubkey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Room, Room, QDistinct> distinctByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Room, Room, QDistinct> distinctByNpub(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'npub', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Room, Room, QDistinct> distinctByOnetimekey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'onetimekey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Room, Room, QDistinct> distinctByPin() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pin');
    });
  }

  QueryBuilder<Room, Room, QDistinct> distinctByPinAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pinAt');
    });
  }

  QueryBuilder<Room, Room, QDistinct> distinctBySignalDecodeError() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'signalDecodeError');
    });
  }

  QueryBuilder<Room, Room, QDistinct> distinctBySignalIdPubkey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'signalIdPubkey',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Room, Room, QDistinct> distinctByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status');
    });
  }

  QueryBuilder<Room, Room, QDistinct> distinctByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'stringify');
    });
  }

  QueryBuilder<Room, Room, QDistinct> distinctByToMainPubkey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'toMainPubkey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Room, Room, QDistinct> distinctByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'type');
    });
  }

  QueryBuilder<Room, Room, QDistinct> distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version');
    });
  }
}

extension RoomQueryProperty on QueryBuilder<Room, Room, QQueryProperty> {
  QueryBuilder<Room, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Room, int, QQueryOperations> autoDeleteDaysProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'autoDeleteDays');
    });
  }

  QueryBuilder<Room, String?, QQueryOperations> avatarProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'avatar');
    });
  }

  QueryBuilder<Room, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<Room, String?, QQueryOperations> curve25519PkHexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'curve25519PkHex');
    });
  }

  QueryBuilder<Room, EncryptMode, QQueryOperations> encryptModeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'encryptMode');
    });
  }

  QueryBuilder<Room, String?, QQueryOperations> groupRelayProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'groupRelay');
    });
  }

  QueryBuilder<Room, GroupType, QQueryOperations> groupTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'groupType');
    });
  }

  QueryBuilder<Room, int, QQueryOperations> hashCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hashCode');
    });
  }

  QueryBuilder<Room, int, QQueryOperations> identityIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'identityId');
    });
  }

  QueryBuilder<Room, bool, QQueryOperations> isMuteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isMute');
    });
  }

  QueryBuilder<Room, String, QQueryOperations> myIdPubkeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'myIdPubkey');
    });
  }

  QueryBuilder<Room, String?, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<Room, String, QQueryOperations> npubProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'npub');
    });
  }

  QueryBuilder<Room, String?, QQueryOperations> onetimekeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'onetimekey');
    });
  }

  QueryBuilder<Room, bool, QQueryOperations> pinProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pin');
    });
  }

  QueryBuilder<Room, DateTime?, QQueryOperations> pinAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pinAt');
    });
  }

  QueryBuilder<Room, bool, QQueryOperations> signalDecodeErrorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'signalDecodeError');
    });
  }

  QueryBuilder<Room, String?, QQueryOperations> signalIdPubkeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'signalIdPubkey');
    });
  }

  QueryBuilder<Room, RoomStatus, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<Room, bool?, QQueryOperations> stringifyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stringify');
    });
  }

  QueryBuilder<Room, String, QQueryOperations> toMainPubkeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'toMainPubkey');
    });
  }

  QueryBuilder<Room, RoomType, QQueryOperations> typeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'type');
    });
  }

  QueryBuilder<Room, int, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }
}

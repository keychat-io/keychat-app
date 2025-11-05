// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_member.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetRoomMemberCollection on Isar {
  IsarCollection<RoomMember> get roomMembers => this.collection();
}

const RoomMemberSchema = CollectionSchema(
  name: r'RoomMember',
  id: 8378385004166137828,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'curve25519PkHex': PropertySchema(
      id: 1,
      name: r'curve25519PkHex',
      type: IsarType.string,
    ),
    r'hashCode': PropertySchema(id: 2, name: r'hashCode', type: IsarType.long),
    r'idPubkey': PropertySchema(
      id: 3,
      name: r'idPubkey',
      type: IsarType.string,
    ),
    r'isAdmin': PropertySchema(id: 4, name: r'isAdmin', type: IsarType.bool),
    r'msg': PropertySchema(id: 5, name: r'msg', type: IsarType.string),
    r'name': PropertySchema(id: 6, name: r'name', type: IsarType.string),
    r'roomId': PropertySchema(id: 7, name: r'roomId', type: IsarType.long),
    r'status': PropertySchema(
      id: 8,
      name: r'status',
      type: IsarType.int,
      enumMap: _RoomMemberstatusEnumValueMap,
    ),
    r'stringify': PropertySchema(
      id: 9,
      name: r'stringify',
      type: IsarType.bool,
    ),
    r'updatedAt': PropertySchema(
      id: 10,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
  },

  estimateSize: _roomMemberEstimateSize,
  serialize: _roomMemberSerialize,
  deserialize: _roomMemberDeserialize,
  deserializeProp: _roomMemberDeserializeProp,
  idName: r'id',
  indexes: {
    r'idPubkey_roomId': IndexSchema(
      id: 5231016433273539527,
      name: r'idPubkey_roomId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'idPubkey',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'roomId',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _roomMemberGetId,
  getLinks: _roomMemberGetLinks,
  attach: _roomMemberAttach,
  version: '3.3.0-dev.3',
);

int _roomMemberEstimateSize(
  RoomMember object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.curve25519PkHex;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.idPubkey.length * 3;
  {
    final value = object.msg;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.name.length * 3;
  return bytesCount;
}

void _roomMemberSerialize(
  RoomMember object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeString(offsets[1], object.curve25519PkHex);
  writer.writeLong(offsets[2], object.hashCode);
  writer.writeString(offsets[3], object.idPubkey);
  writer.writeBool(offsets[4], object.isAdmin);
  writer.writeString(offsets[5], object.msg);
  writer.writeString(offsets[6], object.name);
  writer.writeLong(offsets[7], object.roomId);
  writer.writeInt(offsets[8], object.status.index);
  writer.writeBool(offsets[9], object.stringify);
  writer.writeDateTime(offsets[10], object.updatedAt);
}

RoomMember _roomMemberDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = RoomMember(
    idPubkey: reader.readString(offsets[3]),
    name: reader.readString(offsets[6]),
    roomId: reader.readLong(offsets[7]),
    status:
        _RoomMemberstatusValueEnumMap[reader.readIntOrNull(offsets[8])] ??
        UserStatusType.invited,
  );
  object.createdAt = reader.readDateTimeOrNull(offsets[0]);
  object.curve25519PkHex = reader.readStringOrNull(offsets[1]);
  object.id = id;
  object.isAdmin = reader.readBool(offsets[4]);
  object.msg = reader.readStringOrNull(offsets[5]);
  object.updatedAt = reader.readDateTimeOrNull(offsets[10]);
  return object;
}

P _roomMemberDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readLong(offset)) as P;
    case 8:
      return (_RoomMemberstatusValueEnumMap[reader.readIntOrNull(offset)] ??
              UserStatusType.invited)
          as P;
    case 9:
      return (reader.readBoolOrNull(offset)) as P;
    case 10:
      return (reader.readDateTimeOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _RoomMemberstatusEnumValueMap = {
  'inviting': 0,
  'invited': 1,
  'blocked': 2,
  'removed': 3,
};
const _RoomMemberstatusValueEnumMap = {
  0: UserStatusType.inviting,
  1: UserStatusType.invited,
  2: UserStatusType.blocked,
  3: UserStatusType.removed,
};

Id _roomMemberGetId(RoomMember object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _roomMemberGetLinks(RoomMember object) {
  return [];
}

void _roomMemberAttach(IsarCollection<dynamic> col, Id id, RoomMember object) {
  object.id = id;
}

extension RoomMemberByIndex on IsarCollection<RoomMember> {
  Future<RoomMember?> getByIdPubkeyRoomId(String idPubkey, int roomId) {
    return getByIndex(r'idPubkey_roomId', [idPubkey, roomId]);
  }

  RoomMember? getByIdPubkeyRoomIdSync(String idPubkey, int roomId) {
    return getByIndexSync(r'idPubkey_roomId', [idPubkey, roomId]);
  }

  Future<bool> deleteByIdPubkeyRoomId(String idPubkey, int roomId) {
    return deleteByIndex(r'idPubkey_roomId', [idPubkey, roomId]);
  }

  bool deleteByIdPubkeyRoomIdSync(String idPubkey, int roomId) {
    return deleteByIndexSync(r'idPubkey_roomId', [idPubkey, roomId]);
  }

  Future<List<RoomMember?>> getAllByIdPubkeyRoomId(
    List<String> idPubkeyValues,
    List<int> roomIdValues,
  ) {
    final len = idPubkeyValues.length;
    assert(
      roomIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([idPubkeyValues[i], roomIdValues[i]]);
    }

    return getAllByIndex(r'idPubkey_roomId', values);
  }

  List<RoomMember?> getAllByIdPubkeyRoomIdSync(
    List<String> idPubkeyValues,
    List<int> roomIdValues,
  ) {
    final len = idPubkeyValues.length;
    assert(
      roomIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([idPubkeyValues[i], roomIdValues[i]]);
    }

    return getAllByIndexSync(r'idPubkey_roomId', values);
  }

  Future<int> deleteAllByIdPubkeyRoomId(
    List<String> idPubkeyValues,
    List<int> roomIdValues,
  ) {
    final len = idPubkeyValues.length;
    assert(
      roomIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([idPubkeyValues[i], roomIdValues[i]]);
    }

    return deleteAllByIndex(r'idPubkey_roomId', values);
  }

  int deleteAllByIdPubkeyRoomIdSync(
    List<String> idPubkeyValues,
    List<int> roomIdValues,
  ) {
    final len = idPubkeyValues.length;
    assert(
      roomIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([idPubkeyValues[i], roomIdValues[i]]);
    }

    return deleteAllByIndexSync(r'idPubkey_roomId', values);
  }

  Future<Id> putByIdPubkeyRoomId(RoomMember object) {
    return putByIndex(r'idPubkey_roomId', object);
  }

  Id putByIdPubkeyRoomIdSync(RoomMember object, {bool saveLinks = true}) {
    return putByIndexSync(r'idPubkey_roomId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByIdPubkeyRoomId(List<RoomMember> objects) {
    return putAllByIndex(r'idPubkey_roomId', objects);
  }

  List<Id> putAllByIdPubkeyRoomIdSync(
    List<RoomMember> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'idPubkey_roomId', objects, saveLinks: saveLinks);
  }
}

extension RoomMemberQueryWhereSort
    on QueryBuilder<RoomMember, RoomMember, QWhere> {
  QueryBuilder<RoomMember, RoomMember, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension RoomMemberQueryWhere
    on QueryBuilder<RoomMember, RoomMember, QWhereClause> {
  QueryBuilder<RoomMember, RoomMember, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<RoomMember, RoomMember, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterWhereClause>
  idPubkeyEqualToAnyRoomId(String idPubkey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'idPubkey_roomId',
          value: [idPubkey],
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterWhereClause>
  idPubkeyNotEqualToAnyRoomId(String idPubkey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'idPubkey_roomId',
                lower: [],
                upper: [idPubkey],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'idPubkey_roomId',
                lower: [idPubkey],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'idPubkey_roomId',
                lower: [idPubkey],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'idPubkey_roomId',
                lower: [],
                upper: [idPubkey],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterWhereClause> idPubkeyRoomIdEqualTo(
    String idPubkey,
    int roomId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'idPubkey_roomId',
          value: [idPubkey, roomId],
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterWhereClause>
  idPubkeyEqualToRoomIdNotEqualTo(String idPubkey, int roomId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'idPubkey_roomId',
                lower: [idPubkey],
                upper: [idPubkey, roomId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'idPubkey_roomId',
                lower: [idPubkey, roomId],
                includeLower: false,
                upper: [idPubkey],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'idPubkey_roomId',
                lower: [idPubkey, roomId],
                includeLower: false,
                upper: [idPubkey],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'idPubkey_roomId',
                lower: [idPubkey],
                upper: [idPubkey, roomId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterWhereClause>
  idPubkeyEqualToRoomIdGreaterThan(
    String idPubkey,
    int roomId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'idPubkey_roomId',
          lower: [idPubkey, roomId],
          includeLower: include,
          upper: [idPubkey],
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterWhereClause>
  idPubkeyEqualToRoomIdLessThan(
    String idPubkey,
    int roomId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'idPubkey_roomId',
          lower: [idPubkey],
          upper: [idPubkey, roomId],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterWhereClause>
  idPubkeyEqualToRoomIdBetween(
    String idPubkey,
    int lowerRoomId,
    int upperRoomId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'idPubkey_roomId',
          lower: [idPubkey, lowerRoomId],
          includeLower: includeLower,
          upper: [idPubkey, upperRoomId],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension RoomMemberQueryFilter
    on QueryBuilder<RoomMember, RoomMember, QFilterCondition> {
  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition>
  createdAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'createdAt'),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition>
  createdAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'createdAt'),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> createdAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition>
  createdAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> createdAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> createdAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition>
  curve25519PkHexIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'curve25519PkHex'),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition>
  curve25519PkHexIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'curve25519PkHex'),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition>
  curve25519PkHexEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'curve25519PkHex',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition>
  curve25519PkHexGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'curve25519PkHex',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition>
  curve25519PkHexLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'curve25519PkHex',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition>
  curve25519PkHexBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'curve25519PkHex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition>
  curve25519PkHexStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'curve25519PkHex',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition>
  curve25519PkHexEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'curve25519PkHex',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition>
  curve25519PkHexContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'curve25519PkHex',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition>
  curve25519PkHexMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'curve25519PkHex',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition>
  curve25519PkHexIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'curve25519PkHex', value: ''),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition>
  curve25519PkHexIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'curve25519PkHex', value: ''),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> hashCodeEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'hashCode', value: value),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition>
  hashCodeGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'hashCode',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> hashCodeLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'hashCode',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> hashCodeBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'hashCode',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> idPubkeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'idPubkey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition>
  idPubkeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'idPubkey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> idPubkeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'idPubkey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> idPubkeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'idPubkey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition>
  idPubkeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'idPubkey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> idPubkeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'idPubkey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> idPubkeyContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'idPubkey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> idPubkeyMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'idPubkey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition>
  idPubkeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'idPubkey', value: ''),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition>
  idPubkeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'idPubkey', value: ''),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> isAdminEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isAdmin', value: value),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> msgIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'msg'),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> msgIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'msg'),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> msgEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'msg',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> msgGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'msg',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> msgLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'msg',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> msgBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'msg',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> msgStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'msg',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> msgEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'msg',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> msgContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'msg',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> msgMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'msg',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> msgIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'msg', value: ''),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> msgIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'msg', value: ''),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> nameContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> nameMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> roomIdEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'roomId', value: value),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> roomIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'roomId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> roomIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'roomId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> roomIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'roomId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> statusEqualTo(
    UserStatusType value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'status', value: value),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> statusGreaterThan(
    UserStatusType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'status',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> statusLessThan(
    UserStatusType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'status',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> statusBetween(
    UserStatusType lower,
    UserStatusType upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'status',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition>
  stringifyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'stringify'),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition>
  stringifyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'stringify'),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> stringifyEqualTo(
    bool? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'stringify', value: value),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition>
  updatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'updatedAt'),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition>
  updatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'updatedAt'),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> updatedAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition>
  updatedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> updatedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterFilterCondition> updatedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'updatedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension RoomMemberQueryObject
    on QueryBuilder<RoomMember, RoomMember, QFilterCondition> {}

extension RoomMemberQueryLinks
    on QueryBuilder<RoomMember, RoomMember, QFilterCondition> {}

extension RoomMemberQuerySortBy
    on QueryBuilder<RoomMember, RoomMember, QSortBy> {
  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> sortByCurve25519PkHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'curve25519PkHex', Sort.asc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy>
  sortByCurve25519PkHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'curve25519PkHex', Sort.desc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> sortByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> sortByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> sortByIdPubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'idPubkey', Sort.asc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> sortByIdPubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'idPubkey', Sort.desc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> sortByIsAdmin() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAdmin', Sort.asc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> sortByIsAdminDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAdmin', Sort.desc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> sortByMsg() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'msg', Sort.asc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> sortByMsgDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'msg', Sort.desc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> sortByRoomId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roomId', Sort.asc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> sortByRoomIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roomId', Sort.desc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> sortByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.asc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> sortByStringifyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.desc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension RoomMemberQuerySortThenBy
    on QueryBuilder<RoomMember, RoomMember, QSortThenBy> {
  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> thenByCurve25519PkHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'curve25519PkHex', Sort.asc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy>
  thenByCurve25519PkHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'curve25519PkHex', Sort.desc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> thenByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> thenByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> thenByIdPubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'idPubkey', Sort.asc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> thenByIdPubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'idPubkey', Sort.desc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> thenByIsAdmin() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAdmin', Sort.asc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> thenByIsAdminDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAdmin', Sort.desc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> thenByMsg() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'msg', Sort.asc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> thenByMsgDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'msg', Sort.desc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> thenByRoomId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roomId', Sort.asc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> thenByRoomIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roomId', Sort.desc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> thenByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.asc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> thenByStringifyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.desc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension RoomMemberQueryWhereDistinct
    on QueryBuilder<RoomMember, RoomMember, QDistinct> {
  QueryBuilder<RoomMember, RoomMember, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<RoomMember, RoomMember, QDistinct> distinctByCurve25519PkHex({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'curve25519PkHex',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<RoomMember, RoomMember, QDistinct> distinctByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hashCode');
    });
  }

  QueryBuilder<RoomMember, RoomMember, QDistinct> distinctByIdPubkey({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'idPubkey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QDistinct> distinctByIsAdmin() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isAdmin');
    });
  }

  QueryBuilder<RoomMember, RoomMember, QDistinct> distinctByMsg({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'msg', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<RoomMember, RoomMember, QDistinct> distinctByRoomId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'roomId');
    });
  }

  QueryBuilder<RoomMember, RoomMember, QDistinct> distinctByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status');
    });
  }

  QueryBuilder<RoomMember, RoomMember, QDistinct> distinctByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'stringify');
    });
  }

  QueryBuilder<RoomMember, RoomMember, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension RoomMemberQueryProperty
    on QueryBuilder<RoomMember, RoomMember, QQueryProperty> {
  QueryBuilder<RoomMember, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<RoomMember, DateTime?, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<RoomMember, String?, QQueryOperations>
  curve25519PkHexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'curve25519PkHex');
    });
  }

  QueryBuilder<RoomMember, int, QQueryOperations> hashCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hashCode');
    });
  }

  QueryBuilder<RoomMember, String, QQueryOperations> idPubkeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'idPubkey');
    });
  }

  QueryBuilder<RoomMember, bool, QQueryOperations> isAdminProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isAdmin');
    });
  }

  QueryBuilder<RoomMember, String?, QQueryOperations> msgProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'msg');
    });
  }

  QueryBuilder<RoomMember, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<RoomMember, int, QQueryOperations> roomIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'roomId');
    });
  }

  QueryBuilder<RoomMember, UserStatusType, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<RoomMember, bool?, QQueryOperations> stringifyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stringify');
    });
  }

  QueryBuilder<RoomMember, DateTime?, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RoomMember _$RoomMemberFromJson(Map<String, dynamic> json) =>
    RoomMember(
        idPubkey: json['idPubkey'] as String,
        roomId: (json['roomId'] as num).toInt(),
        name: json['name'] as String,
        status:
            $enumDecodeNullable(_$UserStatusTypeEnumMap, json['status']) ??
            UserStatusType.invited,
      )
      ..createdAt = json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String)
      ..updatedAt = json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String)
      ..isAdmin = json['isAdmin'] as bool
      ..msg = json['msg'] as String?;

Map<String, dynamic> _$RoomMemberToJson(RoomMember instance) =>
    <String, dynamic>{
      'idPubkey': instance.idPubkey,
      'roomId': instance.roomId,
      'name': instance.name,
      'createdAt': ?instance.createdAt?.toIso8601String(),
      'updatedAt': ?instance.updatedAt?.toIso8601String(),
      'isAdmin': instance.isAdmin,
      'status': _$UserStatusTypeEnumMap[instance.status]!,
      'msg': ?instance.msg,
    };

const _$UserStatusTypeEnumMap = {
  UserStatusType.inviting: 'inviting',
  UserStatusType.invited: 'invited',
  UserStatusType.blocked: 'blocked',
  UserStatusType.removed: 'removed',
};

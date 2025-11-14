// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mykey.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMykeyCollection on Isar {
  IsarCollection<Mykey> get mykeys => this.collection();
}

const MykeySchema = CollectionSchema(
  name: r'Mykey',
  id: -2041963381219106739,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'hashCode': PropertySchema(id: 1, name: r'hashCode', type: IsarType.long),
    r'identityId': PropertySchema(
      id: 2,
      name: r'identityId',
      type: IsarType.long,
    ),
    r'isOneTime': PropertySchema(
      id: 3,
      name: r'isOneTime',
      type: IsarType.bool,
    ),
    r'needDelete': PropertySchema(
      id: 4,
      name: r'needDelete',
      type: IsarType.bool,
    ),
    r'oneTimeUsed': PropertySchema(
      id: 5,
      name: r'oneTimeUsed',
      type: IsarType.bool,
    ),
    r'prikey': PropertySchema(id: 6, name: r'prikey', type: IsarType.string),
    r'pubkey': PropertySchema(id: 7, name: r'pubkey', type: IsarType.string),
    r'roomId': PropertySchema(id: 8, name: r'roomId', type: IsarType.long),
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

  estimateSize: _mykeyEstimateSize,
  serialize: _mykeySerialize,
  deserialize: _mykeyDeserialize,
  deserializeProp: _mykeyDeserializeProp,
  idName: r'id',
  indexes: {
    r'pubkey_identityId': IndexSchema(
      id: -6048679425391964269,
      name: r'pubkey_identityId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'pubkey',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'identityId',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _mykeyGetId,
  getLinks: _mykeyGetLinks,
  attach: _mykeyAttach,
  version: '3.3.0',
);

int _mykeyEstimateSize(
  Mykey object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.prikey.length * 3;
  bytesCount += 3 + object.pubkey.length * 3;
  return bytesCount;
}

void _mykeySerialize(
  Mykey object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeLong(offsets[1], object.hashCode);
  writer.writeLong(offsets[2], object.identityId);
  writer.writeBool(offsets[3], object.isOneTime);
  writer.writeBool(offsets[4], object.needDelete);
  writer.writeBool(offsets[5], object.oneTimeUsed);
  writer.writeString(offsets[6], object.prikey);
  writer.writeString(offsets[7], object.pubkey);
  writer.writeLong(offsets[8], object.roomId);
  writer.writeBool(offsets[9], object.stringify);
  writer.writeDateTime(offsets[10], object.updatedAt);
}

Mykey _mykeyDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Mykey(
    identityId: reader.readLong(offsets[2]),
    prikey: reader.readString(offsets[6]),
    pubkey: reader.readString(offsets[7]),
  );
  object.createdAt = reader.readDateTime(offsets[0]);
  object.id = id;
  object.isOneTime = reader.readBool(offsets[3]);
  object.needDelete = reader.readBool(offsets[4]);
  object.oneTimeUsed = reader.readBool(offsets[5]);
  object.roomId = reader.readLongOrNull(offsets[8]);
  object.updatedAt = reader.readDateTime(offsets[10]);
  return object;
}

P _mykeyDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readBool(offset)) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readLongOrNull(offset)) as P;
    case 9:
      return (reader.readBoolOrNull(offset)) as P;
    case 10:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _mykeyGetId(Mykey object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _mykeyGetLinks(Mykey object) {
  return [];
}

void _mykeyAttach(IsarCollection<dynamic> col, Id id, Mykey object) {
  object.id = id;
}

extension MykeyByIndex on IsarCollection<Mykey> {
  Future<Mykey?> getByPubkeyIdentityId(String pubkey, int identityId) {
    return getByIndex(r'pubkey_identityId', [pubkey, identityId]);
  }

  Mykey? getByPubkeyIdentityIdSync(String pubkey, int identityId) {
    return getByIndexSync(r'pubkey_identityId', [pubkey, identityId]);
  }

  Future<bool> deleteByPubkeyIdentityId(String pubkey, int identityId) {
    return deleteByIndex(r'pubkey_identityId', [pubkey, identityId]);
  }

  bool deleteByPubkeyIdentityIdSync(String pubkey, int identityId) {
    return deleteByIndexSync(r'pubkey_identityId', [pubkey, identityId]);
  }

  Future<List<Mykey?>> getAllByPubkeyIdentityId(
    List<String> pubkeyValues,
    List<int> identityIdValues,
  ) {
    final len = pubkeyValues.length;
    assert(
      identityIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([pubkeyValues[i], identityIdValues[i]]);
    }

    return getAllByIndex(r'pubkey_identityId', values);
  }

  List<Mykey?> getAllByPubkeyIdentityIdSync(
    List<String> pubkeyValues,
    List<int> identityIdValues,
  ) {
    final len = pubkeyValues.length;
    assert(
      identityIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([pubkeyValues[i], identityIdValues[i]]);
    }

    return getAllByIndexSync(r'pubkey_identityId', values);
  }

  Future<int> deleteAllByPubkeyIdentityId(
    List<String> pubkeyValues,
    List<int> identityIdValues,
  ) {
    final len = pubkeyValues.length;
    assert(
      identityIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([pubkeyValues[i], identityIdValues[i]]);
    }

    return deleteAllByIndex(r'pubkey_identityId', values);
  }

  int deleteAllByPubkeyIdentityIdSync(
    List<String> pubkeyValues,
    List<int> identityIdValues,
  ) {
    final len = pubkeyValues.length;
    assert(
      identityIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([pubkeyValues[i], identityIdValues[i]]);
    }

    return deleteAllByIndexSync(r'pubkey_identityId', values);
  }

  Future<Id> putByPubkeyIdentityId(Mykey object) {
    return putByIndex(r'pubkey_identityId', object);
  }

  Id putByPubkeyIdentityIdSync(Mykey object, {bool saveLinks = true}) {
    return putByIndexSync(r'pubkey_identityId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByPubkeyIdentityId(List<Mykey> objects) {
    return putAllByIndex(r'pubkey_identityId', objects);
  }

  List<Id> putAllByPubkeyIdentityIdSync(
    List<Mykey> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'pubkey_identityId',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension MykeyQueryWhereSort on QueryBuilder<Mykey, Mykey, QWhere> {
  QueryBuilder<Mykey, Mykey, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension MykeyQueryWhere on QueryBuilder<Mykey, Mykey, QWhereClause> {
  QueryBuilder<Mykey, Mykey, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<Mykey, Mykey, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterWhereClause> idBetween(
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

  QueryBuilder<Mykey, Mykey, QAfterWhereClause> pubkeyEqualToAnyIdentityId(
    String pubkey,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'pubkey_identityId',
          value: [pubkey],
        ),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterWhereClause> pubkeyNotEqualToAnyIdentityId(
    String pubkey,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'pubkey_identityId',
                lower: [],
                upper: [pubkey],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'pubkey_identityId',
                lower: [pubkey],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'pubkey_identityId',
                lower: [pubkey],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'pubkey_identityId',
                lower: [],
                upper: [pubkey],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterWhereClause> pubkeyIdentityIdEqualTo(
    String pubkey,
    int identityId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'pubkey_identityId',
          value: [pubkey, identityId],
        ),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterWhereClause>
  pubkeyEqualToIdentityIdNotEqualTo(String pubkey, int identityId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'pubkey_identityId',
                lower: [pubkey],
                upper: [pubkey, identityId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'pubkey_identityId',
                lower: [pubkey, identityId],
                includeLower: false,
                upper: [pubkey],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'pubkey_identityId',
                lower: [pubkey, identityId],
                includeLower: false,
                upper: [pubkey],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'pubkey_identityId',
                lower: [pubkey],
                upper: [pubkey, identityId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterWhereClause>
  pubkeyEqualToIdentityIdGreaterThan(
    String pubkey,
    int identityId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'pubkey_identityId',
          lower: [pubkey, identityId],
          includeLower: include,
          upper: [pubkey],
        ),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterWhereClause> pubkeyEqualToIdentityIdLessThan(
    String pubkey,
    int identityId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'pubkey_identityId',
          lower: [pubkey],
          upper: [pubkey, identityId],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterWhereClause> pubkeyEqualToIdentityIdBetween(
    String pubkey,
    int lowerIdentityId,
    int upperIdentityId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'pubkey_identityId',
          lower: [pubkey, lowerIdentityId],
          includeLower: includeLower,
          upper: [pubkey, upperIdentityId],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension MykeyQueryFilter on QueryBuilder<Mykey, Mykey, QFilterCondition> {
  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> createdAtEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
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

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> createdAtLessThan(
    DateTime value, {
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

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> createdAtBetween(
    DateTime lower,
    DateTime upper, {
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

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> hashCodeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'hashCode', value: value),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> hashCodeGreaterThan(
    int value, {
    bool include = false,
  }) {
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

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> hashCodeLessThan(
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

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> hashCodeBetween(
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

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> idBetween(
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

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> identityIdEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'identityId', value: value),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> identityIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'identityId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> identityIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'identityId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> identityIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'identityId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> isOneTimeEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isOneTime', value: value),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> needDeleteEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'needDelete', value: value),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> oneTimeUsedEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'oneTimeUsed', value: value),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> prikeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'prikey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> prikeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'prikey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> prikeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'prikey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> prikeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'prikey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> prikeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'prikey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> prikeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'prikey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> prikeyContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'prikey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> prikeyMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'prikey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> prikeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'prikey', value: ''),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> prikeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'prikey', value: ''),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> pubkeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'pubkey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> pubkeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'pubkey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> pubkeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'pubkey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> pubkeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'pubkey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> pubkeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'pubkey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> pubkeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'pubkey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> pubkeyContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'pubkey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> pubkeyMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'pubkey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> pubkeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'pubkey', value: ''),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> pubkeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'pubkey', value: ''),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> roomIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'roomId'),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> roomIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'roomId'),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> roomIdEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'roomId', value: value),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> roomIdGreaterThan(
    int? value, {
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

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> roomIdLessThan(
    int? value, {
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

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> roomIdBetween(
    int? lower,
    int? upper, {
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

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> stringifyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'stringify'),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> stringifyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'stringify'),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> stringifyEqualTo(
    bool? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'stringify', value: value),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> updatedAtEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> updatedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
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

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> updatedAtLessThan(
    DateTime value, {
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

  QueryBuilder<Mykey, Mykey, QAfterFilterCondition> updatedAtBetween(
    DateTime lower,
    DateTime upper, {
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

extension MykeyQueryObject on QueryBuilder<Mykey, Mykey, QFilterCondition> {}

extension MykeyQueryLinks on QueryBuilder<Mykey, Mykey, QFilterCondition> {}

extension MykeyQuerySortBy on QueryBuilder<Mykey, Mykey, QSortBy> {
  QueryBuilder<Mykey, Mykey, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> sortByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> sortByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> sortByIdentityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identityId', Sort.asc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> sortByIdentityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identityId', Sort.desc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> sortByIsOneTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOneTime', Sort.asc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> sortByIsOneTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOneTime', Sort.desc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> sortByNeedDelete() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'needDelete', Sort.asc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> sortByNeedDeleteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'needDelete', Sort.desc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> sortByOneTimeUsed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'oneTimeUsed', Sort.asc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> sortByOneTimeUsedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'oneTimeUsed', Sort.desc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> sortByPrikey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'prikey', Sort.asc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> sortByPrikeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'prikey', Sort.desc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> sortByPubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pubkey', Sort.asc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> sortByPubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pubkey', Sort.desc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> sortByRoomId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roomId', Sort.asc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> sortByRoomIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roomId', Sort.desc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> sortByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.asc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> sortByStringifyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.desc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension MykeyQuerySortThenBy on QueryBuilder<Mykey, Mykey, QSortThenBy> {
  QueryBuilder<Mykey, Mykey, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> thenByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> thenByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> thenByIdentityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identityId', Sort.asc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> thenByIdentityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identityId', Sort.desc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> thenByIsOneTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOneTime', Sort.asc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> thenByIsOneTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOneTime', Sort.desc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> thenByNeedDelete() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'needDelete', Sort.asc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> thenByNeedDeleteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'needDelete', Sort.desc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> thenByOneTimeUsed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'oneTimeUsed', Sort.asc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> thenByOneTimeUsedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'oneTimeUsed', Sort.desc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> thenByPrikey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'prikey', Sort.asc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> thenByPrikeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'prikey', Sort.desc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> thenByPubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pubkey', Sort.asc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> thenByPubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pubkey', Sort.desc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> thenByRoomId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roomId', Sort.asc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> thenByRoomIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roomId', Sort.desc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> thenByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.asc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> thenByStringifyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.desc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<Mykey, Mykey, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension MykeyQueryWhereDistinct on QueryBuilder<Mykey, Mykey, QDistinct> {
  QueryBuilder<Mykey, Mykey, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<Mykey, Mykey, QDistinct> distinctByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hashCode');
    });
  }

  QueryBuilder<Mykey, Mykey, QDistinct> distinctByIdentityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'identityId');
    });
  }

  QueryBuilder<Mykey, Mykey, QDistinct> distinctByIsOneTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isOneTime');
    });
  }

  QueryBuilder<Mykey, Mykey, QDistinct> distinctByNeedDelete() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'needDelete');
    });
  }

  QueryBuilder<Mykey, Mykey, QDistinct> distinctByOneTimeUsed() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'oneTimeUsed');
    });
  }

  QueryBuilder<Mykey, Mykey, QDistinct> distinctByPrikey({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'prikey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Mykey, Mykey, QDistinct> distinctByPubkey({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pubkey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Mykey, Mykey, QDistinct> distinctByRoomId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'roomId');
    });
  }

  QueryBuilder<Mykey, Mykey, QDistinct> distinctByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'stringify');
    });
  }

  QueryBuilder<Mykey, Mykey, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension MykeyQueryProperty on QueryBuilder<Mykey, Mykey, QQueryProperty> {
  QueryBuilder<Mykey, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Mykey, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<Mykey, int, QQueryOperations> hashCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hashCode');
    });
  }

  QueryBuilder<Mykey, int, QQueryOperations> identityIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'identityId');
    });
  }

  QueryBuilder<Mykey, bool, QQueryOperations> isOneTimeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isOneTime');
    });
  }

  QueryBuilder<Mykey, bool, QQueryOperations> needDeleteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'needDelete');
    });
  }

  QueryBuilder<Mykey, bool, QQueryOperations> oneTimeUsedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'oneTimeUsed');
    });
  }

  QueryBuilder<Mykey, String, QQueryOperations> prikeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'prikey');
    });
  }

  QueryBuilder<Mykey, String, QQueryOperations> pubkeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pubkey');
    });
  }

  QueryBuilder<Mykey, int?, QQueryOperations> roomIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'roomId');
    });
  }

  QueryBuilder<Mykey, bool?, QQueryOperations> stringifyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stringify');
    });
  }

  QueryBuilder<Mykey, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}

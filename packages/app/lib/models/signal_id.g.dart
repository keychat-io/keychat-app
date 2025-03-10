// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'signal_id.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSignalIdCollection on Isar {
  IsarCollection<SignalId> get signalIds => this.collection();
}

const SignalIdSchema = CollectionSchema(
  name: r'SignalId',
  id: -5852883728276925435,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'hashCode': PropertySchema(
      id: 1,
      name: r'hashCode',
      type: IsarType.long,
    ),
    r'identityId': PropertySchema(
      id: 2,
      name: r'identityId',
      type: IsarType.long,
    ),
    r'isGroupSharedKey': PropertySchema(
      id: 3,
      name: r'isGroupSharedKey',
      type: IsarType.bool,
    ),
    r'isUsed': PropertySchema(
      id: 4,
      name: r'isUsed',
      type: IsarType.bool,
    ),
    r'keys': PropertySchema(
      id: 5,
      name: r'keys',
      type: IsarType.string,
    ),
    r'needDelete': PropertySchema(
      id: 6,
      name: r'needDelete',
      type: IsarType.bool,
    ),
    r'prikey': PropertySchema(
      id: 7,
      name: r'prikey',
      type: IsarType.string,
    ),
    r'pubkey': PropertySchema(
      id: 8,
      name: r'pubkey',
      type: IsarType.string,
    ),
    r'signalKeyId': PropertySchema(
      id: 9,
      name: r'signalKeyId',
      type: IsarType.long,
    ),
    r'stringify': PropertySchema(
      id: 10,
      name: r'stringify',
      type: IsarType.bool,
    ),
    r'updatedAt': PropertySchema(
      id: 11,
      name: r'updatedAt',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _signalIdEstimateSize,
  serialize: _signalIdSerialize,
  deserialize: _signalIdDeserialize,
  deserializeProp: _signalIdDeserializeProp,
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
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _signalIdGetId,
  getLinks: _signalIdGetLinks,
  attach: _signalIdAttach,
  version: '3.1.8',
);

int _signalIdEstimateSize(
  SignalId object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.keys;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.prikey.length * 3;
  bytesCount += 3 + object.pubkey.length * 3;
  return bytesCount;
}

void _signalIdSerialize(
  SignalId object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeLong(offsets[1], object.hashCode);
  writer.writeLong(offsets[2], object.identityId);
  writer.writeBool(offsets[3], object.isGroupSharedKey);
  writer.writeBool(offsets[4], object.isUsed);
  writer.writeString(offsets[5], object.keys);
  writer.writeBool(offsets[6], object.needDelete);
  writer.writeString(offsets[7], object.prikey);
  writer.writeString(offsets[8], object.pubkey);
  writer.writeLong(offsets[9], object.signalKeyId);
  writer.writeBool(offsets[10], object.stringify);
  writer.writeDateTime(offsets[11], object.updatedAt);
}

SignalId _signalIdDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SignalId(
    identityId: reader.readLong(offsets[2]),
    prikey: reader.readString(offsets[7]),
    pubkey: reader.readString(offsets[8]),
  );
  object.createdAt = reader.readDateTime(offsets[0]);
  object.id = id;
  object.isGroupSharedKey = reader.readBool(offsets[3]);
  object.isUsed = reader.readBool(offsets[4]);
  object.keys = reader.readStringOrNull(offsets[5]);
  object.needDelete = reader.readBool(offsets[6]);
  object.signalKeyId = reader.readLongOrNull(offsets[9]);
  object.updatedAt = reader.readDateTime(offsets[11]);
  return object;
}

P _signalIdDeserializeProp<P>(
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
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readBool(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readLongOrNull(offset)) as P;
    case 10:
      return (reader.readBoolOrNull(offset)) as P;
    case 11:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _signalIdGetId(SignalId object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _signalIdGetLinks(SignalId object) {
  return [];
}

void _signalIdAttach(IsarCollection<dynamic> col, Id id, SignalId object) {
  object.id = id;
}

extension SignalIdByIndex on IsarCollection<SignalId> {
  Future<SignalId?> getByPubkeyIdentityId(String pubkey, int identityId) {
    return getByIndex(r'pubkey_identityId', [pubkey, identityId]);
  }

  SignalId? getByPubkeyIdentityIdSync(String pubkey, int identityId) {
    return getByIndexSync(r'pubkey_identityId', [pubkey, identityId]);
  }

  Future<bool> deleteByPubkeyIdentityId(String pubkey, int identityId) {
    return deleteByIndex(r'pubkey_identityId', [pubkey, identityId]);
  }

  bool deleteByPubkeyIdentityIdSync(String pubkey, int identityId) {
    return deleteByIndexSync(r'pubkey_identityId', [pubkey, identityId]);
  }

  Future<List<SignalId?>> getAllByPubkeyIdentityId(
      List<String> pubkeyValues, List<int> identityIdValues) {
    final len = pubkeyValues.length;
    assert(identityIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([pubkeyValues[i], identityIdValues[i]]);
    }

    return getAllByIndex(r'pubkey_identityId', values);
  }

  List<SignalId?> getAllByPubkeyIdentityIdSync(
      List<String> pubkeyValues, List<int> identityIdValues) {
    final len = pubkeyValues.length;
    assert(identityIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([pubkeyValues[i], identityIdValues[i]]);
    }

    return getAllByIndexSync(r'pubkey_identityId', values);
  }

  Future<int> deleteAllByPubkeyIdentityId(
      List<String> pubkeyValues, List<int> identityIdValues) {
    final len = pubkeyValues.length;
    assert(identityIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([pubkeyValues[i], identityIdValues[i]]);
    }

    return deleteAllByIndex(r'pubkey_identityId', values);
  }

  int deleteAllByPubkeyIdentityIdSync(
      List<String> pubkeyValues, List<int> identityIdValues) {
    final len = pubkeyValues.length;
    assert(identityIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([pubkeyValues[i], identityIdValues[i]]);
    }

    return deleteAllByIndexSync(r'pubkey_identityId', values);
  }

  Future<Id> putByPubkeyIdentityId(SignalId object) {
    return putByIndex(r'pubkey_identityId', object);
  }

  Id putByPubkeyIdentityIdSync(SignalId object, {bool saveLinks = true}) {
    return putByIndexSync(r'pubkey_identityId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByPubkeyIdentityId(List<SignalId> objects) {
    return putAllByIndex(r'pubkey_identityId', objects);
  }

  List<Id> putAllByPubkeyIdentityIdSync(List<SignalId> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'pubkey_identityId', objects,
        saveLinks: saveLinks);
  }
}

extension SignalIdQueryWhereSort on QueryBuilder<SignalId, SignalId, QWhere> {
  QueryBuilder<SignalId, SignalId, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SignalIdQueryWhere on QueryBuilder<SignalId, SignalId, QWhereClause> {
  QueryBuilder<SignalId, SignalId, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<SignalId, SignalId, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterWhereClause> idBetween(
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

  QueryBuilder<SignalId, SignalId, QAfterWhereClause>
      pubkeyEqualToAnyIdentityId(String pubkey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'pubkey_identityId',
        value: [pubkey],
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterWhereClause>
      pubkeyNotEqualToAnyIdentityId(String pubkey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'pubkey_identityId',
              lower: [],
              upper: [pubkey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'pubkey_identityId',
              lower: [pubkey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'pubkey_identityId',
              lower: [pubkey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'pubkey_identityId',
              lower: [],
              upper: [pubkey],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterWhereClause> pubkeyIdentityIdEqualTo(
      String pubkey, int identityId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'pubkey_identityId',
        value: [pubkey, identityId],
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterWhereClause>
      pubkeyEqualToIdentityIdNotEqualTo(String pubkey, int identityId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'pubkey_identityId',
              lower: [pubkey],
              upper: [pubkey, identityId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'pubkey_identityId',
              lower: [pubkey, identityId],
              includeLower: false,
              upper: [pubkey],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'pubkey_identityId',
              lower: [pubkey, identityId],
              includeLower: false,
              upper: [pubkey],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'pubkey_identityId',
              lower: [pubkey],
              upper: [pubkey, identityId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterWhereClause>
      pubkeyEqualToIdentityIdGreaterThan(
    String pubkey,
    int identityId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'pubkey_identityId',
        lower: [pubkey, identityId],
        includeLower: include,
        upper: [pubkey],
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterWhereClause>
      pubkeyEqualToIdentityIdLessThan(
    String pubkey,
    int identityId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'pubkey_identityId',
        lower: [pubkey],
        upper: [pubkey, identityId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterWhereClause>
      pubkeyEqualToIdentityIdBetween(
    String pubkey,
    int lowerIdentityId,
    int upperIdentityId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'pubkey_identityId',
        lower: [pubkey, lowerIdentityId],
        includeLower: includeLower,
        upper: [pubkey, upperIdentityId],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension SignalIdQueryFilter
    on QueryBuilder<SignalId, SignalId, QFilterCondition> {
  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> createdAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> createdAtGreaterThan(
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

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> createdAtLessThan(
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

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> createdAtBetween(
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

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> hashCodeEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hashCode',
        value: value,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> hashCodeGreaterThan(
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

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> hashCodeLessThan(
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

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> hashCodeBetween(
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

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> idBetween(
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

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> identityIdEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'identityId',
        value: value,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> identityIdGreaterThan(
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

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> identityIdLessThan(
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

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> identityIdBetween(
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

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition>
      isGroupSharedKeyEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isGroupSharedKey',
        value: value,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> isUsedEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isUsed',
        value: value,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> keysIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'keys',
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> keysIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'keys',
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> keysEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'keys',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> keysGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'keys',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> keysLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'keys',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> keysBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'keys',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> keysStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'keys',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> keysEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'keys',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> keysContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'keys',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> keysMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'keys',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> keysIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'keys',
        value: '',
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> keysIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'keys',
        value: '',
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> needDeleteEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'needDelete',
        value: value,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> prikeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'prikey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> prikeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'prikey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> prikeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'prikey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> prikeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'prikey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> prikeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'prikey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> prikeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'prikey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> prikeyContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'prikey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> prikeyMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'prikey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> prikeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'prikey',
        value: '',
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> prikeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'prikey',
        value: '',
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> pubkeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> pubkeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'pubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> pubkeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'pubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> pubkeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'pubkey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> pubkeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'pubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> pubkeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'pubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> pubkeyContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'pubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> pubkeyMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'pubkey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> pubkeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pubkey',
        value: '',
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> pubkeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'pubkey',
        value: '',
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> signalKeyIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'signalKeyId',
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition>
      signalKeyIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'signalKeyId',
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> signalKeyIdEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'signalKeyId',
        value: value,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition>
      signalKeyIdGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'signalKeyId',
        value: value,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> signalKeyIdLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'signalKeyId',
        value: value,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> signalKeyIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'signalKeyId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> stringifyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'stringify',
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> stringifyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'stringify',
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> stringifyEqualTo(
      bool? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'stringify',
        value: value,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> updatedAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> updatedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> updatedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterFilterCondition> updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension SignalIdQueryObject
    on QueryBuilder<SignalId, SignalId, QFilterCondition> {}

extension SignalIdQueryLinks
    on QueryBuilder<SignalId, SignalId, QFilterCondition> {}

extension SignalIdQuerySortBy on QueryBuilder<SignalId, SignalId, QSortBy> {
  QueryBuilder<SignalId, SignalId, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> sortByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> sortByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> sortByIdentityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identityId', Sort.asc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> sortByIdentityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identityId', Sort.desc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> sortByIsGroupSharedKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isGroupSharedKey', Sort.asc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> sortByIsGroupSharedKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isGroupSharedKey', Sort.desc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> sortByIsUsed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isUsed', Sort.asc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> sortByIsUsedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isUsed', Sort.desc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> sortByKeys() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keys', Sort.asc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> sortByKeysDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keys', Sort.desc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> sortByNeedDelete() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'needDelete', Sort.asc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> sortByNeedDeleteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'needDelete', Sort.desc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> sortByPrikey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'prikey', Sort.asc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> sortByPrikeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'prikey', Sort.desc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> sortByPubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pubkey', Sort.asc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> sortByPubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pubkey', Sort.desc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> sortBySignalKeyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signalKeyId', Sort.asc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> sortBySignalKeyIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signalKeyId', Sort.desc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> sortByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.asc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> sortByStringifyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.desc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension SignalIdQuerySortThenBy
    on QueryBuilder<SignalId, SignalId, QSortThenBy> {
  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenByIdentityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identityId', Sort.asc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenByIdentityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identityId', Sort.desc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenByIsGroupSharedKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isGroupSharedKey', Sort.asc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenByIsGroupSharedKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isGroupSharedKey', Sort.desc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenByIsUsed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isUsed', Sort.asc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenByIsUsedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isUsed', Sort.desc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenByKeys() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keys', Sort.asc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenByKeysDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keys', Sort.desc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenByNeedDelete() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'needDelete', Sort.asc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenByNeedDeleteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'needDelete', Sort.desc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenByPrikey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'prikey', Sort.asc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenByPrikeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'prikey', Sort.desc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenByPubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pubkey', Sort.asc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenByPubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pubkey', Sort.desc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenBySignalKeyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signalKeyId', Sort.asc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenBySignalKeyIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signalKeyId', Sort.desc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.asc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenByStringifyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.desc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<SignalId, SignalId, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension SignalIdQueryWhereDistinct
    on QueryBuilder<SignalId, SignalId, QDistinct> {
  QueryBuilder<SignalId, SignalId, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<SignalId, SignalId, QDistinct> distinctByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hashCode');
    });
  }

  QueryBuilder<SignalId, SignalId, QDistinct> distinctByIdentityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'identityId');
    });
  }

  QueryBuilder<SignalId, SignalId, QDistinct> distinctByIsGroupSharedKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isGroupSharedKey');
    });
  }

  QueryBuilder<SignalId, SignalId, QDistinct> distinctByIsUsed() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isUsed');
    });
  }

  QueryBuilder<SignalId, SignalId, QDistinct> distinctByKeys(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'keys', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SignalId, SignalId, QDistinct> distinctByNeedDelete() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'needDelete');
    });
  }

  QueryBuilder<SignalId, SignalId, QDistinct> distinctByPrikey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'prikey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SignalId, SignalId, QDistinct> distinctByPubkey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pubkey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SignalId, SignalId, QDistinct> distinctBySignalKeyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'signalKeyId');
    });
  }

  QueryBuilder<SignalId, SignalId, QDistinct> distinctByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'stringify');
    });
  }

  QueryBuilder<SignalId, SignalId, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension SignalIdQueryProperty
    on QueryBuilder<SignalId, SignalId, QQueryProperty> {
  QueryBuilder<SignalId, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SignalId, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<SignalId, int, QQueryOperations> hashCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hashCode');
    });
  }

  QueryBuilder<SignalId, int, QQueryOperations> identityIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'identityId');
    });
  }

  QueryBuilder<SignalId, bool, QQueryOperations> isGroupSharedKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isGroupSharedKey');
    });
  }

  QueryBuilder<SignalId, bool, QQueryOperations> isUsedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isUsed');
    });
  }

  QueryBuilder<SignalId, String?, QQueryOperations> keysProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'keys');
    });
  }

  QueryBuilder<SignalId, bool, QQueryOperations> needDeleteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'needDelete');
    });
  }

  QueryBuilder<SignalId, String, QQueryOperations> prikeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'prikey');
    });
  }

  QueryBuilder<SignalId, String, QQueryOperations> pubkeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pubkey');
    });
  }

  QueryBuilder<SignalId, int?, QQueryOperations> signalKeyIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'signalKeyId');
    });
  }

  QueryBuilder<SignalId, bool?, QQueryOperations> stringifyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stringify');
    });
  }

  QueryBuilder<SignalId, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}

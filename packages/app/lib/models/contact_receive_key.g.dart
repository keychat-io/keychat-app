// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact_receive_key.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetContactReceiveKeyCollection on Isar {
  IsarCollection<ContactReceiveKey> get contactReceiveKeys => this.collection();
}

const ContactReceiveKeySchema = CollectionSchema(
  name: r'ContactReceiveKey',
  id: -6957644385311737856,
  properties: {
    r'hashCode': PropertySchema(id: 0, name: r'hashCode', type: IsarType.long),
    r'identityId': PropertySchema(
      id: 1,
      name: r'identityId',
      type: IsarType.long,
    ),
    r'isMute': PropertySchema(id: 2, name: r'isMute', type: IsarType.bool),
    r'pubkey': PropertySchema(id: 3, name: r'pubkey', type: IsarType.string),
    r'receiveKeys': PropertySchema(
      id: 4,
      name: r'receiveKeys',
      type: IsarType.stringList,
    ),
    r'removeReceiveKeys': PropertySchema(
      id: 5,
      name: r'removeReceiveKeys',
      type: IsarType.stringList,
    ),
    r'roomId': PropertySchema(id: 6, name: r'roomId', type: IsarType.long),
    r'stringify': PropertySchema(
      id: 7,
      name: r'stringify',
      type: IsarType.bool,
    ),
  },

  estimateSize: _contactReceiveKeyEstimateSize,
  serialize: _contactReceiveKeySerialize,
  deserialize: _contactReceiveKeyDeserialize,
  deserializeProp: _contactReceiveKeyDeserializeProp,
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

  getId: _contactReceiveKeyGetId,
  getLinks: _contactReceiveKeyGetLinks,
  attach: _contactReceiveKeyAttach,
  version: '3.3.0-dev.3',
);

int _contactReceiveKeyEstimateSize(
  ContactReceiveKey object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.pubkey.length * 3;
  bytesCount += 3 + object.receiveKeys.length * 3;
  {
    for (var i = 0; i < object.receiveKeys.length; i++) {
      final value = object.receiveKeys[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.removeReceiveKeys.length * 3;
  {
    for (var i = 0; i < object.removeReceiveKeys.length; i++) {
      final value = object.removeReceiveKeys[i];
      bytesCount += value.length * 3;
    }
  }
  return bytesCount;
}

void _contactReceiveKeySerialize(
  ContactReceiveKey object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.hashCode);
  writer.writeLong(offsets[1], object.identityId);
  writer.writeBool(offsets[2], object.isMute);
  writer.writeString(offsets[3], object.pubkey);
  writer.writeStringList(offsets[4], object.receiveKeys);
  writer.writeStringList(offsets[5], object.removeReceiveKeys);
  writer.writeLong(offsets[6], object.roomId);
  writer.writeBool(offsets[7], object.stringify);
}

ContactReceiveKey _contactReceiveKeyDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ContactReceiveKey(
    identityId: reader.readLong(offsets[1]),
    pubkey: reader.readString(offsets[3]),
  );
  object.id = id;
  object.isMute = reader.readBool(offsets[2]);
  object.receiveKeys = reader.readStringList(offsets[4]) ?? [];
  object.removeReceiveKeys = reader.readStringList(offsets[5]) ?? [];
  object.roomId = reader.readLong(offsets[6]);
  return object;
}

P _contactReceiveKeyDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readStringList(offset) ?? []) as P;
    case 5:
      return (reader.readStringList(offset) ?? []) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readBoolOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _contactReceiveKeyGetId(ContactReceiveKey object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _contactReceiveKeyGetLinks(
  ContactReceiveKey object,
) {
  return [];
}

void _contactReceiveKeyAttach(
  IsarCollection<dynamic> col,
  Id id,
  ContactReceiveKey object,
) {
  object.id = id;
}

extension ContactReceiveKeyByIndex on IsarCollection<ContactReceiveKey> {
  Future<ContactReceiveKey?> getByPubkeyIdentityId(
    String pubkey,
    int identityId,
  ) {
    return getByIndex(r'pubkey_identityId', [pubkey, identityId]);
  }

  ContactReceiveKey? getByPubkeyIdentityIdSync(String pubkey, int identityId) {
    return getByIndexSync(r'pubkey_identityId', [pubkey, identityId]);
  }

  Future<bool> deleteByPubkeyIdentityId(String pubkey, int identityId) {
    return deleteByIndex(r'pubkey_identityId', [pubkey, identityId]);
  }

  bool deleteByPubkeyIdentityIdSync(String pubkey, int identityId) {
    return deleteByIndexSync(r'pubkey_identityId', [pubkey, identityId]);
  }

  Future<List<ContactReceiveKey?>> getAllByPubkeyIdentityId(
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

  List<ContactReceiveKey?> getAllByPubkeyIdentityIdSync(
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

  Future<Id> putByPubkeyIdentityId(ContactReceiveKey object) {
    return putByIndex(r'pubkey_identityId', object);
  }

  Id putByPubkeyIdentityIdSync(
    ContactReceiveKey object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(r'pubkey_identityId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByPubkeyIdentityId(List<ContactReceiveKey> objects) {
    return putAllByIndex(r'pubkey_identityId', objects);
  }

  List<Id> putAllByPubkeyIdentityIdSync(
    List<ContactReceiveKey> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'pubkey_identityId',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension ContactReceiveKeyQueryWhereSort
    on QueryBuilder<ContactReceiveKey, ContactReceiveKey, QWhere> {
  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ContactReceiveKeyQueryWhere
    on QueryBuilder<ContactReceiveKey, ContactReceiveKey, QWhereClause> {
  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterWhereClause>
  idNotEqualTo(Id id) {
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterWhereClause>
  idBetween(
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterWhereClause>
  pubkeyEqualToAnyIdentityId(String pubkey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'pubkey_identityId',
          value: [pubkey],
        ),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterWhereClause>
  pubkeyNotEqualToAnyIdentityId(String pubkey) {
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterWhereClause>
  pubkeyIdentityIdEqualTo(String pubkey, int identityId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'pubkey_identityId',
          value: [pubkey, identityId],
        ),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterWhereClause>
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterWhereClause>
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterWhereClause>
  pubkeyEqualToIdentityIdLessThan(
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterWhereClause>
  pubkeyEqualToIdentityIdBetween(
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

extension ContactReceiveKeyQueryFilter
    on QueryBuilder<ContactReceiveKey, ContactReceiveKey, QFilterCondition> {
  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  hashCodeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'hashCode', value: value),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  hashCodeLessThan(int value, {bool include = false}) {
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  hashCodeBetween(
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  idBetween(
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  identityIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'identityId', value: value),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  identityIdGreaterThan(int value, {bool include = false}) {
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  identityIdLessThan(int value, {bool include = false}) {
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  identityIdBetween(
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  isMuteEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isMute', value: value),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  pubkeyEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  pubkeyGreaterThan(
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  pubkeyLessThan(
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  pubkeyBetween(
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  pubkeyStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  pubkeyEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  pubkeyContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  pubkeyMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  pubkeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'pubkey', value: ''),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  pubkeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'pubkey', value: ''),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  receiveKeysElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'receiveKeys',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  receiveKeysElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'receiveKeys',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  receiveKeysElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'receiveKeys',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  receiveKeysElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'receiveKeys',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  receiveKeysElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'receiveKeys',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  receiveKeysElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'receiveKeys',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  receiveKeysElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'receiveKeys',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  receiveKeysElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'receiveKeys',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  receiveKeysElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'receiveKeys', value: ''),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  receiveKeysElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'receiveKeys', value: ''),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  receiveKeysLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'receiveKeys', length, true, length, true);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  receiveKeysIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'receiveKeys', 0, true, 0, true);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  receiveKeysIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'receiveKeys', 0, false, 999999, true);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  receiveKeysLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'receiveKeys', 0, true, length, include);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  receiveKeysLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'receiveKeys', length, include, 999999, true);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  receiveKeysLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'receiveKeys',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  removeReceiveKeysElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'removeReceiveKeys',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  removeReceiveKeysElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'removeReceiveKeys',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  removeReceiveKeysElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'removeReceiveKeys',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  removeReceiveKeysElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'removeReceiveKeys',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  removeReceiveKeysElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'removeReceiveKeys',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  removeReceiveKeysElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'removeReceiveKeys',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  removeReceiveKeysElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'removeReceiveKeys',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  removeReceiveKeysElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'removeReceiveKeys',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  removeReceiveKeysElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'removeReceiveKeys', value: ''),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  removeReceiveKeysElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'removeReceiveKeys', value: ''),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  removeReceiveKeysLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'removeReceiveKeys', length, true, length, true);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  removeReceiveKeysIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'removeReceiveKeys', 0, true, 0, true);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  removeReceiveKeysIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'removeReceiveKeys', 0, false, 999999, true);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  removeReceiveKeysLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'removeReceiveKeys', 0, true, length, include);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  removeReceiveKeysLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'removeReceiveKeys',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  removeReceiveKeysLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'removeReceiveKeys',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  roomIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'roomId', value: value),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  roomIdGreaterThan(int value, {bool include = false}) {
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  roomIdLessThan(int value, {bool include = false}) {
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  roomIdBetween(
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

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  stringifyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'stringify'),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  stringifyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'stringify'),
      );
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterFilterCondition>
  stringifyEqualTo(bool? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'stringify', value: value),
      );
    });
  }
}

extension ContactReceiveKeyQueryObject
    on QueryBuilder<ContactReceiveKey, ContactReceiveKey, QFilterCondition> {}

extension ContactReceiveKeyQueryLinks
    on QueryBuilder<ContactReceiveKey, ContactReceiveKey, QFilterCondition> {}

extension ContactReceiveKeyQuerySortBy
    on QueryBuilder<ContactReceiveKey, ContactReceiveKey, QSortBy> {
  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy>
  sortByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy>
  sortByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy>
  sortByIdentityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identityId', Sort.asc);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy>
  sortByIdentityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identityId', Sort.desc);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy>
  sortByIsMute() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isMute', Sort.asc);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy>
  sortByIsMuteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isMute', Sort.desc);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy>
  sortByPubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pubkey', Sort.asc);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy>
  sortByPubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pubkey', Sort.desc);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy>
  sortByRoomId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roomId', Sort.asc);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy>
  sortByRoomIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roomId', Sort.desc);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy>
  sortByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.asc);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy>
  sortByStringifyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.desc);
    });
  }
}

extension ContactReceiveKeyQuerySortThenBy
    on QueryBuilder<ContactReceiveKey, ContactReceiveKey, QSortThenBy> {
  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy>
  thenByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy>
  thenByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy>
  thenByIdentityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identityId', Sort.asc);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy>
  thenByIdentityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identityId', Sort.desc);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy>
  thenByIsMute() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isMute', Sort.asc);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy>
  thenByIsMuteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isMute', Sort.desc);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy>
  thenByPubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pubkey', Sort.asc);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy>
  thenByPubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pubkey', Sort.desc);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy>
  thenByRoomId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roomId', Sort.asc);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy>
  thenByRoomIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roomId', Sort.desc);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy>
  thenByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.asc);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QAfterSortBy>
  thenByStringifyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.desc);
    });
  }
}

extension ContactReceiveKeyQueryWhereDistinct
    on QueryBuilder<ContactReceiveKey, ContactReceiveKey, QDistinct> {
  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QDistinct>
  distinctByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hashCode');
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QDistinct>
  distinctByIdentityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'identityId');
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QDistinct>
  distinctByIsMute() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isMute');
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QDistinct>
  distinctByPubkey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pubkey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QDistinct>
  distinctByReceiveKeys() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'receiveKeys');
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QDistinct>
  distinctByRemoveReceiveKeys() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'removeReceiveKeys');
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QDistinct>
  distinctByRoomId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'roomId');
    });
  }

  QueryBuilder<ContactReceiveKey, ContactReceiveKey, QDistinct>
  distinctByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'stringify');
    });
  }
}

extension ContactReceiveKeyQueryProperty
    on QueryBuilder<ContactReceiveKey, ContactReceiveKey, QQueryProperty> {
  QueryBuilder<ContactReceiveKey, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ContactReceiveKey, int, QQueryOperations> hashCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hashCode');
    });
  }

  QueryBuilder<ContactReceiveKey, int, QQueryOperations> identityIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'identityId');
    });
  }

  QueryBuilder<ContactReceiveKey, bool, QQueryOperations> isMuteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isMute');
    });
  }

  QueryBuilder<ContactReceiveKey, String, QQueryOperations> pubkeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pubkey');
    });
  }

  QueryBuilder<ContactReceiveKey, List<String>, QQueryOperations>
  receiveKeysProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'receiveKeys');
    });
  }

  QueryBuilder<ContactReceiveKey, List<String>, QQueryOperations>
  removeReceiveKeysProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'removeReceiveKeys');
    });
  }

  QueryBuilder<ContactReceiveKey, int, QQueryOperations> roomIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'roomId');
    });
  }

  QueryBuilder<ContactReceiveKey, bool?, QQueryOperations> stringifyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stringify');
    });
  }
}

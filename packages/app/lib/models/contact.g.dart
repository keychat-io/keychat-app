// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetContactCollection on Isar {
  IsarCollection<Contact> get contacts => this.collection();
}

const ContactSchema = CollectionSchema(
  name: r'Contact',
  id: 342568039478732666,
  properties: {
    r'about': PropertySchema(id: 0, name: r'about', type: IsarType.string),
    r'aboutFromRelay': PropertySchema(
      id: 1,
      name: r'aboutFromRelay',
      type: IsarType.string,
    ),
    r'autoCreateFromGroup': PropertySchema(
      id: 2,
      name: r'autoCreateFromGroup',
      type: IsarType.bool,
    ),
    r'avatarFromRelay': PropertySchema(
      id: 3,
      name: r'avatarFromRelay',
      type: IsarType.string,
    ),
    r'avatarFromRelayLocalPath': PropertySchema(
      id: 4,
      name: r'avatarFromRelayLocalPath',
      type: IsarType.string,
    ),
    r'avatarLocalPath': PropertySchema(
      id: 5,
      name: r'avatarLocalPath',
      type: IsarType.string,
    ),
    r'avatarRemoteUrl': PropertySchema(
      id: 6,
      name: r'avatarRemoteUrl',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 7,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'curve25519PkHex': PropertySchema(
      id: 8,
      name: r'curve25519PkHex',
      type: IsarType.string,
    ),
    r'fetchFromRelayAt': PropertySchema(
      id: 9,
      name: r'fetchFromRelayAt',
      type: IsarType.dateTime,
    ),
    r'hashCode': PropertySchema(id: 10, name: r'hashCode', type: IsarType.long),
    r'identityId': PropertySchema(
      id: 11,
      name: r'identityId',
      type: IsarType.long,
    ),
    r'lightning': PropertySchema(
      id: 12,
      name: r'lightning',
      type: IsarType.string,
    ),
    r'metadata': PropertySchema(
      id: 13,
      name: r'metadata',
      type: IsarType.string,
    ),
    r'metadataFromRelay': PropertySchema(
      id: 14,
      name: r'metadataFromRelay',
      type: IsarType.string,
    ),
    r'name': PropertySchema(id: 15, name: r'name', type: IsarType.string),
    r'nameFromRelay': PropertySchema(
      id: 16,
      name: r'nameFromRelay',
      type: IsarType.string,
    ),
    r'npubkey': PropertySchema(id: 17, name: r'npubkey', type: IsarType.string),
    r'petname': PropertySchema(id: 18, name: r'petname', type: IsarType.string),
    r'pubkey': PropertySchema(id: 19, name: r'pubkey', type: IsarType.string),
    r'stringify': PropertySchema(
      id: 20,
      name: r'stringify',
      type: IsarType.bool,
    ),
    r'updatedAt': PropertySchema(
      id: 21,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'version': PropertySchema(id: 22, name: r'version', type: IsarType.long),
    r'versionFromRelay': PropertySchema(
      id: 23,
      name: r'versionFromRelay',
      type: IsarType.long,
    ),
  },

  estimateSize: _contactEstimateSize,
  serialize: _contactSerialize,
  deserialize: _contactDeserialize,
  deserializeProp: _contactDeserializeProp,
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

  getId: _contactGetId,
  getLinks: _contactGetLinks,
  attach: _contactAttach,
  version: '3.3.0',
);

int _contactEstimateSize(
  Contact object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.about;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.aboutFromRelay;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.avatarFromRelay;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.avatarFromRelayLocalPath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.avatarLocalPath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.avatarRemoteUrl;
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
    final value = object.lightning;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.metadata;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.metadataFromRelay;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.name;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.nameFromRelay;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.npubkey.length * 3;
  {
    final value = object.petname;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.pubkey.length * 3;
  return bytesCount;
}

void _contactSerialize(
  Contact object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.about);
  writer.writeString(offsets[1], object.aboutFromRelay);
  writer.writeBool(offsets[2], object.autoCreateFromGroup);
  writer.writeString(offsets[3], object.avatarFromRelay);
  writer.writeString(offsets[4], object.avatarFromRelayLocalPath);
  writer.writeString(offsets[5], object.avatarLocalPath);
  writer.writeString(offsets[6], object.avatarRemoteUrl);
  writer.writeDateTime(offsets[7], object.createdAt);
  writer.writeString(offsets[8], object.curve25519PkHex);
  writer.writeDateTime(offsets[9], object.fetchFromRelayAt);
  writer.writeLong(offsets[10], object.hashCode);
  writer.writeLong(offsets[11], object.identityId);
  writer.writeString(offsets[12], object.lightning);
  writer.writeString(offsets[13], object.metadata);
  writer.writeString(offsets[14], object.metadataFromRelay);
  writer.writeString(offsets[15], object.name);
  writer.writeString(offsets[16], object.nameFromRelay);
  writer.writeString(offsets[17], object.npubkey);
  writer.writeString(offsets[18], object.petname);
  writer.writeString(offsets[19], object.pubkey);
  writer.writeBool(offsets[20], object.stringify);
  writer.writeDateTime(offsets[21], object.updatedAt);
  writer.writeLong(offsets[22], object.version);
  writer.writeLong(offsets[23], object.versionFromRelay);
}

Contact _contactDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Contact(
    identityId: reader.readLong(offsets[11]),
    npubkey: reader.readStringOrNull(offsets[17]) ?? '',
    pubkey: reader.readString(offsets[19]),
  );
  object.about = reader.readStringOrNull(offsets[0]);
  object.aboutFromRelay = reader.readStringOrNull(offsets[1]);
  object.autoCreateFromGroup = reader.readBool(offsets[2]);
  object.avatarFromRelay = reader.readStringOrNull(offsets[3]);
  object.avatarFromRelayLocalPath = reader.readStringOrNull(offsets[4]);
  object.avatarLocalPath = reader.readStringOrNull(offsets[5]);
  object.avatarRemoteUrl = reader.readStringOrNull(offsets[6]);
  object.createdAt = reader.readDateTimeOrNull(offsets[7]);
  object.curve25519PkHex = reader.readStringOrNull(offsets[8]);
  object.fetchFromRelayAt = reader.readDateTimeOrNull(offsets[9]);
  object.id = id;
  object.lightning = reader.readStringOrNull(offsets[12]);
  object.metadata = reader.readStringOrNull(offsets[13]);
  object.metadataFromRelay = reader.readStringOrNull(offsets[14]);
  object.name = reader.readStringOrNull(offsets[15]);
  object.nameFromRelay = reader.readStringOrNull(offsets[16]);
  object.petname = reader.readStringOrNull(offsets[18]);
  object.updatedAt = reader.readDateTimeOrNull(offsets[21]);
  object.version = reader.readLong(offsets[22]);
  object.versionFromRelay = reader.readLong(offsets[23]);
  return object;
}

P _contactDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 10:
      return (reader.readLong(offset)) as P;
    case 11:
      return (reader.readLong(offset)) as P;
    case 12:
      return (reader.readStringOrNull(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    case 16:
      return (reader.readStringOrNull(offset)) as P;
    case 17:
      return (reader.readStringOrNull(offset) ?? '') as P;
    case 18:
      return (reader.readStringOrNull(offset)) as P;
    case 19:
      return (reader.readString(offset)) as P;
    case 20:
      return (reader.readBoolOrNull(offset)) as P;
    case 21:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 22:
      return (reader.readLong(offset)) as P;
    case 23:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _contactGetId(Contact object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _contactGetLinks(Contact object) {
  return [];
}

void _contactAttach(IsarCollection<dynamic> col, Id id, Contact object) {
  object.id = id;
}

extension ContactByIndex on IsarCollection<Contact> {
  Future<Contact?> getByPubkeyIdentityId(String pubkey, int identityId) {
    return getByIndex(r'pubkey_identityId', [pubkey, identityId]);
  }

  Contact? getByPubkeyIdentityIdSync(String pubkey, int identityId) {
    return getByIndexSync(r'pubkey_identityId', [pubkey, identityId]);
  }

  Future<bool> deleteByPubkeyIdentityId(String pubkey, int identityId) {
    return deleteByIndex(r'pubkey_identityId', [pubkey, identityId]);
  }

  bool deleteByPubkeyIdentityIdSync(String pubkey, int identityId) {
    return deleteByIndexSync(r'pubkey_identityId', [pubkey, identityId]);
  }

  Future<List<Contact?>> getAllByPubkeyIdentityId(
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

  List<Contact?> getAllByPubkeyIdentityIdSync(
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

  Future<Id> putByPubkeyIdentityId(Contact object) {
    return putByIndex(r'pubkey_identityId', object);
  }

  Id putByPubkeyIdentityIdSync(Contact object, {bool saveLinks = true}) {
    return putByIndexSync(r'pubkey_identityId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByPubkeyIdentityId(List<Contact> objects) {
    return putAllByIndex(r'pubkey_identityId', objects);
  }

  List<Id> putAllByPubkeyIdentityIdSync(
    List<Contact> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'pubkey_identityId',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension ContactQueryWhereSort on QueryBuilder<Contact, Contact, QWhere> {
  QueryBuilder<Contact, Contact, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ContactQueryWhere on QueryBuilder<Contact, Contact, QWhereClause> {
  QueryBuilder<Contact, Contact, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<Contact, Contact, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<Contact, Contact, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterWhereClause> idBetween(
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

  QueryBuilder<Contact, Contact, QAfterWhereClause> pubkeyEqualToAnyIdentityId(
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

  QueryBuilder<Contact, Contact, QAfterWhereClause>
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

  QueryBuilder<Contact, Contact, QAfterWhereClause> pubkeyIdentityIdEqualTo(
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

  QueryBuilder<Contact, Contact, QAfterWhereClause>
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

  QueryBuilder<Contact, Contact, QAfterWhereClause>
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

  QueryBuilder<Contact, Contact, QAfterWhereClause>
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

  QueryBuilder<Contact, Contact, QAfterWhereClause>
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

extension ContactQueryFilter
    on QueryBuilder<Contact, Contact, QFilterCondition> {
  QueryBuilder<Contact, Contact, QAfterFilterCondition> aboutIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'about'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> aboutIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'about'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> aboutEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'about',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> aboutGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'about',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> aboutLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'about',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> aboutBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'about',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> aboutStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'about',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> aboutEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'about',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> aboutContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'about',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> aboutMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'about',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> aboutIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'about', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> aboutIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'about', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> aboutFromRelayIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'aboutFromRelay'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  aboutFromRelayIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'aboutFromRelay'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> aboutFromRelayEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'aboutFromRelay',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  aboutFromRelayGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'aboutFromRelay',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> aboutFromRelayLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'aboutFromRelay',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> aboutFromRelayBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'aboutFromRelay',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  aboutFromRelayStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'aboutFromRelay',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> aboutFromRelayEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'aboutFromRelay',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> aboutFromRelayContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'aboutFromRelay',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> aboutFromRelayMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'aboutFromRelay',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  aboutFromRelayIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'aboutFromRelay', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  aboutFromRelayIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'aboutFromRelay', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  autoCreateFromGroupEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'autoCreateFromGroup', value: value),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarFromRelayIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'avatarFromRelay'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarFromRelayIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'avatarFromRelay'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarFromRelayEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'avatarFromRelay',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarFromRelayGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'avatarFromRelay',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarFromRelayLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'avatarFromRelay',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarFromRelayBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'avatarFromRelay',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarFromRelayStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'avatarFromRelay',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarFromRelayEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'avatarFromRelay',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarFromRelayContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'avatarFromRelay',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarFromRelayMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'avatarFromRelay',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarFromRelayIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'avatarFromRelay', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarFromRelayIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'avatarFromRelay', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarFromRelayLocalPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'avatarFromRelayLocalPath'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarFromRelayLocalPathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'avatarFromRelayLocalPath'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarFromRelayLocalPathEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'avatarFromRelayLocalPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarFromRelayLocalPathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'avatarFromRelayLocalPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarFromRelayLocalPathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'avatarFromRelayLocalPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarFromRelayLocalPathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'avatarFromRelayLocalPath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarFromRelayLocalPathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'avatarFromRelayLocalPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarFromRelayLocalPathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'avatarFromRelayLocalPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarFromRelayLocalPathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'avatarFromRelayLocalPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarFromRelayLocalPathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'avatarFromRelayLocalPath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarFromRelayLocalPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'avatarFromRelayLocalPath',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarFromRelayLocalPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'avatarFromRelayLocalPath',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarLocalPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'avatarLocalPath'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarLocalPathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'avatarLocalPath'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarLocalPathEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'avatarLocalPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarLocalPathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'avatarLocalPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarLocalPathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'avatarLocalPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarLocalPathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'avatarLocalPath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarLocalPathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'avatarLocalPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarLocalPathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'avatarLocalPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarLocalPathContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'avatarLocalPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarLocalPathMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'avatarLocalPath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarLocalPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'avatarLocalPath', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarLocalPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'avatarLocalPath', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarRemoteUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'avatarRemoteUrl'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarRemoteUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'avatarRemoteUrl'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarRemoteUrlEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'avatarRemoteUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarRemoteUrlGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'avatarRemoteUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarRemoteUrlLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'avatarRemoteUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarRemoteUrlBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'avatarRemoteUrl',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarRemoteUrlStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'avatarRemoteUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarRemoteUrlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'avatarRemoteUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarRemoteUrlContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'avatarRemoteUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarRemoteUrlMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'avatarRemoteUrl',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarRemoteUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'avatarRemoteUrl', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  avatarRemoteUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'avatarRemoteUrl', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> createdAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'createdAt'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> createdAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'createdAt'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> createdAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> createdAtGreaterThan(
    DateTime? value, {
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> createdAtLessThan(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> createdAtBetween(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  curve25519PkHexIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'curve25519PkHex'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  curve25519PkHexIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'curve25519PkHex'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> curve25519PkHexEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> curve25519PkHexLessThan(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> curve25519PkHexBetween(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> curve25519PkHexEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> curve25519PkHexContains(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> curve25519PkHexMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  curve25519PkHexIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'curve25519PkHex', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  curve25519PkHexIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'curve25519PkHex', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  fetchFromRelayAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'fetchFromRelayAt'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  fetchFromRelayAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'fetchFromRelayAt'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> fetchFromRelayAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'fetchFromRelayAt', value: value),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  fetchFromRelayAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'fetchFromRelayAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  fetchFromRelayAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'fetchFromRelayAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> fetchFromRelayAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'fetchFromRelayAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> hashCodeEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'hashCode', value: value),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> hashCodeGreaterThan(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> hashCodeLessThan(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> hashCodeBetween(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> idBetween(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> identityIdEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'identityId', value: value),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> identityIdGreaterThan(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> identityIdLessThan(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> identityIdBetween(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> lightningIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lightning'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> lightningIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lightning'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> lightningEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'lightning',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> lightningGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lightning',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> lightningLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lightning',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> lightningBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lightning',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> lightningStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'lightning',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> lightningEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'lightning',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> lightningContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'lightning',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> lightningMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'lightning',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> lightningIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lightning', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> lightningIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'lightning', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> metadataIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'metadata'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> metadataIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'metadata'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> metadataEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'metadata',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> metadataGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'metadata',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> metadataLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'metadata',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> metadataBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'metadata',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> metadataStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'metadata',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> metadataEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'metadata',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> metadataContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'metadata',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> metadataMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'metadata',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> metadataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'metadata', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> metadataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'metadata', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  metadataFromRelayIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'metadataFromRelay'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  metadataFromRelayIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'metadataFromRelay'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  metadataFromRelayEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'metadataFromRelay',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  metadataFromRelayGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'metadataFromRelay',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  metadataFromRelayLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'metadataFromRelay',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  metadataFromRelayBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'metadataFromRelay',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  metadataFromRelayStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'metadataFromRelay',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  metadataFromRelayEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'metadataFromRelay',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  metadataFromRelayContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'metadataFromRelay',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  metadataFromRelayMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'metadataFromRelay',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  metadataFromRelayIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'metadataFromRelay', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  metadataFromRelayIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'metadataFromRelay', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'name'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'name'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameEqualTo(
    String? value, {
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameGreaterThan(
    String? value, {
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameLessThan(
    String? value, {
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameBetween(
    String? lower,
    String? upper, {
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameStartsWith(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameEndsWith(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameContains(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameMatches(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameFromRelayIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'nameFromRelay'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  nameFromRelayIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'nameFromRelay'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameFromRelayEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'nameFromRelay',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  nameFromRelayGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'nameFromRelay',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameFromRelayLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'nameFromRelay',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameFromRelayBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'nameFromRelay',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameFromRelayStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'nameFromRelay',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameFromRelayEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'nameFromRelay',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameFromRelayContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'nameFromRelay',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameFromRelayMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'nameFromRelay',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameFromRelayIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'nameFromRelay', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  nameFromRelayIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'nameFromRelay', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> npubkeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'npubkey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> npubkeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'npubkey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> npubkeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'npubkey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> npubkeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'npubkey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> npubkeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'npubkey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> npubkeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'npubkey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> npubkeyContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'npubkey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> npubkeyMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'npubkey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> npubkeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'npubkey', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> npubkeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'npubkey', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> petnameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'petname'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> petnameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'petname'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> petnameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'petname',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> petnameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'petname',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> petnameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'petname',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> petnameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'petname',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> petnameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'petname',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> petnameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'petname',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> petnameContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'petname',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> petnameMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'petname',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> petnameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'petname', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> petnameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'petname', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> pubkeyEqualTo(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> pubkeyGreaterThan(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> pubkeyLessThan(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> pubkeyBetween(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> pubkeyStartsWith(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> pubkeyEndsWith(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> pubkeyContains(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> pubkeyMatches(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> pubkeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'pubkey', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> pubkeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'pubkey', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> stringifyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'stringify'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> stringifyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'stringify'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> stringifyEqualTo(
    bool? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'stringify', value: value),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> updatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'updatedAt'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> updatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'updatedAt'),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> updatedAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> updatedAtGreaterThan(
    DateTime? value, {
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> updatedAtLessThan(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> updatedAtBetween(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> versionEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'version', value: value),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> versionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'version',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> versionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'version',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> versionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'version',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> versionFromRelayEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'versionFromRelay', value: value),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  versionFromRelayGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'versionFromRelay',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition>
  versionFromRelayLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'versionFromRelay',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> versionFromRelayBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'versionFromRelay',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ContactQueryObject
    on QueryBuilder<Contact, Contact, QFilterCondition> {}

extension ContactQueryLinks
    on QueryBuilder<Contact, Contact, QFilterCondition> {}

extension ContactQuerySortBy on QueryBuilder<Contact, Contact, QSortBy> {
  QueryBuilder<Contact, Contact, QAfterSortBy> sortByAbout() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'about', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByAboutDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'about', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByAboutFromRelay() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aboutFromRelay', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByAboutFromRelayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aboutFromRelay', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByAutoCreateFromGroup() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoCreateFromGroup', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByAutoCreateFromGroupDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoCreateFromGroup', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByAvatarFromRelay() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avatarFromRelay', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByAvatarFromRelayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avatarFromRelay', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy>
  sortByAvatarFromRelayLocalPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avatarFromRelayLocalPath', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy>
  sortByAvatarFromRelayLocalPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avatarFromRelayLocalPath', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByAvatarLocalPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avatarLocalPath', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByAvatarLocalPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avatarLocalPath', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByAvatarRemoteUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avatarRemoteUrl', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByAvatarRemoteUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avatarRemoteUrl', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByCurve25519PkHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'curve25519PkHex', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByCurve25519PkHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'curve25519PkHex', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByFetchFromRelayAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fetchFromRelayAt', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByFetchFromRelayAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fetchFromRelayAt', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByIdentityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identityId', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByIdentityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identityId', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByLightning() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lightning', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByLightningDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lightning', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByMetadata() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadata', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByMetadataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadata', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByMetadataFromRelay() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataFromRelay', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByMetadataFromRelayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataFromRelay', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByNameFromRelay() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nameFromRelay', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByNameFromRelayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nameFromRelay', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByNpubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'npubkey', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByNpubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'npubkey', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByPetname() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'petname', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByPetnameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'petname', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByPubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pubkey', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByPubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pubkey', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByStringifyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByVersionFromRelay() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionFromRelay', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByVersionFromRelayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionFromRelay', Sort.desc);
    });
  }
}

extension ContactQuerySortThenBy
    on QueryBuilder<Contact, Contact, QSortThenBy> {
  QueryBuilder<Contact, Contact, QAfterSortBy> thenByAbout() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'about', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByAboutDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'about', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByAboutFromRelay() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aboutFromRelay', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByAboutFromRelayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aboutFromRelay', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByAutoCreateFromGroup() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoCreateFromGroup', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByAutoCreateFromGroupDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoCreateFromGroup', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByAvatarFromRelay() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avatarFromRelay', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByAvatarFromRelayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avatarFromRelay', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy>
  thenByAvatarFromRelayLocalPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avatarFromRelayLocalPath', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy>
  thenByAvatarFromRelayLocalPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avatarFromRelayLocalPath', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByAvatarLocalPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avatarLocalPath', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByAvatarLocalPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avatarLocalPath', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByAvatarRemoteUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avatarRemoteUrl', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByAvatarRemoteUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avatarRemoteUrl', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByCurve25519PkHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'curve25519PkHex', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByCurve25519PkHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'curve25519PkHex', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByFetchFromRelayAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fetchFromRelayAt', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByFetchFromRelayAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fetchFromRelayAt', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByIdentityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identityId', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByIdentityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identityId', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByLightning() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lightning', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByLightningDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lightning', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByMetadata() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadata', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByMetadataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadata', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByMetadataFromRelay() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataFromRelay', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByMetadataFromRelayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataFromRelay', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByNameFromRelay() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nameFromRelay', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByNameFromRelayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nameFromRelay', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByNpubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'npubkey', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByNpubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'npubkey', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByPetname() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'petname', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByPetnameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'petname', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByPubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pubkey', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByPubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pubkey', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByStringifyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByVersionFromRelay() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionFromRelay', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByVersionFromRelayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionFromRelay', Sort.desc);
    });
  }
}

extension ContactQueryWhereDistinct
    on QueryBuilder<Contact, Contact, QDistinct> {
  QueryBuilder<Contact, Contact, QDistinct> distinctByAbout({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'about', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByAboutFromRelay({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'aboutFromRelay',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByAutoCreateFromGroup() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'autoCreateFromGroup');
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByAvatarFromRelay({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'avatarFromRelay',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByAvatarFromRelayLocalPath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'avatarFromRelayLocalPath',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByAvatarLocalPath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'avatarLocalPath',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByAvatarRemoteUrl({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'avatarRemoteUrl',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByCurve25519PkHex({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'curve25519PkHex',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByFetchFromRelayAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fetchFromRelayAt');
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hashCode');
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByIdentityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'identityId');
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByLightning({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lightning', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByMetadata({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'metadata', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByMetadataFromRelay({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'metadataFromRelay',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByNameFromRelay({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'nameFromRelay',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByNpubkey({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'npubkey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByPetname({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'petname', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByPubkey({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pubkey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'stringify');
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version');
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByVersionFromRelay() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'versionFromRelay');
    });
  }
}

extension ContactQueryProperty
    on QueryBuilder<Contact, Contact, QQueryProperty> {
  QueryBuilder<Contact, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Contact, String?, QQueryOperations> aboutProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'about');
    });
  }

  QueryBuilder<Contact, String?, QQueryOperations> aboutFromRelayProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'aboutFromRelay');
    });
  }

  QueryBuilder<Contact, bool, QQueryOperations> autoCreateFromGroupProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'autoCreateFromGroup');
    });
  }

  QueryBuilder<Contact, String?, QQueryOperations> avatarFromRelayProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'avatarFromRelay');
    });
  }

  QueryBuilder<Contact, String?, QQueryOperations>
  avatarFromRelayLocalPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'avatarFromRelayLocalPath');
    });
  }

  QueryBuilder<Contact, String?, QQueryOperations> avatarLocalPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'avatarLocalPath');
    });
  }

  QueryBuilder<Contact, String?, QQueryOperations> avatarRemoteUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'avatarRemoteUrl');
    });
  }

  QueryBuilder<Contact, DateTime?, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<Contact, String?, QQueryOperations> curve25519PkHexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'curve25519PkHex');
    });
  }

  QueryBuilder<Contact, DateTime?, QQueryOperations>
  fetchFromRelayAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fetchFromRelayAt');
    });
  }

  QueryBuilder<Contact, int, QQueryOperations> hashCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hashCode');
    });
  }

  QueryBuilder<Contact, int, QQueryOperations> identityIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'identityId');
    });
  }

  QueryBuilder<Contact, String?, QQueryOperations> lightningProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lightning');
    });
  }

  QueryBuilder<Contact, String?, QQueryOperations> metadataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'metadata');
    });
  }

  QueryBuilder<Contact, String?, QQueryOperations> metadataFromRelayProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'metadataFromRelay');
    });
  }

  QueryBuilder<Contact, String?, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<Contact, String?, QQueryOperations> nameFromRelayProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nameFromRelay');
    });
  }

  QueryBuilder<Contact, String, QQueryOperations> npubkeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'npubkey');
    });
  }

  QueryBuilder<Contact, String?, QQueryOperations> petnameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'petname');
    });
  }

  QueryBuilder<Contact, String, QQueryOperations> pubkeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pubkey');
    });
  }

  QueryBuilder<Contact, bool?, QQueryOperations> stringifyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stringify');
    });
  }

  QueryBuilder<Contact, DateTime?, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<Contact, int, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }

  QueryBuilder<Contact, int, QQueryOperations> versionFromRelayProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'versionFromRelay');
    });
  }
}

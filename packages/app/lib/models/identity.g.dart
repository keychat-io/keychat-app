// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'identity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetIdentityCollection on Isar {
  IsarCollection<Identity> get identitys => this.collection();
}

const IdentitySchema = CollectionSchema(
  name: r'Identity',
  id: 1410733637558640605,
  properties: {
    r'about': PropertySchema(
      id: 0,
      name: r'about',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'curve25519Pk': PropertySchema(
      id: 2,
      name: r'curve25519Pk',
      type: IsarType.byteList,
    ),
    r'curve25519PkHex': PropertySchema(
      id: 3,
      name: r'curve25519PkHex',
      type: IsarType.string,
    ),
    r'curve25519Sk': PropertySchema(
      id: 4,
      name: r'curve25519Sk',
      type: IsarType.byteList,
    ),
    r'curve25519SkHex': PropertySchema(
      id: 5,
      name: r'curve25519SkHex',
      type: IsarType.string,
    ),
    r'hashCode': PropertySchema(
      id: 6,
      name: r'hashCode',
      type: IsarType.long,
    ),
    r'isDefault': PropertySchema(
      id: 7,
      name: r'isDefault',
      type: IsarType.bool,
    ),
    r'mnemonic': PropertySchema(
      id: 8,
      name: r'mnemonic',
      type: IsarType.string,
    ),
    r'name': PropertySchema(
      id: 9,
      name: r'name',
      type: IsarType.string,
    ),
    r'note': PropertySchema(
      id: 10,
      name: r'note',
      type: IsarType.string,
    ),
    r'npub': PropertySchema(
      id: 11,
      name: r'npub',
      type: IsarType.string,
    ),
    r'nsec': PropertySchema(
      id: 12,
      name: r'nsec',
      type: IsarType.string,
    ),
    r'secp256k1PKHex': PropertySchema(
      id: 13,
      name: r'secp256k1PKHex',
      type: IsarType.string,
    ),
    r'secp256k1SKHex': PropertySchema(
      id: 14,
      name: r'secp256k1SKHex',
      type: IsarType.string,
    ),
    r'stringify': PropertySchema(
      id: 15,
      name: r'stringify',
      type: IsarType.bool,
    ),
    r'weight': PropertySchema(
      id: 16,
      name: r'weight',
      type: IsarType.long,
    )
  },
  estimateSize: _identityEstimateSize,
  serialize: _identitySerialize,
  deserialize: _identityDeserialize,
  deserializeProp: _identityDeserializeProp,
  idName: r'id',
  indexes: {
    r'curve25519PkHex': IndexSchema(
      id: 2327133715061765490,
      name: r'curve25519PkHex',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'curve25519PkHex',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _identityGetId,
  getLinks: _identityGetLinks,
  attach: _identityAttach,
  version: '3.1.0+1',
);

int _identityEstimateSize(
  Identity object,
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
  bytesCount += 3 + object.curve25519Pk.length;
  bytesCount += 3 + object.curve25519PkHex.length * 3;
  bytesCount += 3 + object.curve25519Sk.length;
  bytesCount += 3 + object.curve25519SkHex.length * 3;
  bytesCount += 3 + object.mnemonic.length * 3;
  bytesCount += 3 + object.name.length * 3;
  {
    final value = object.note;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.npub.length * 3;
  bytesCount += 3 + object.nsec.length * 3;
  bytesCount += 3 + object.secp256k1PKHex.length * 3;
  bytesCount += 3 + object.secp256k1SKHex.length * 3;
  return bytesCount;
}

void _identitySerialize(
  Identity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.about);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeByteList(offsets[2], object.curve25519Pk);
  writer.writeString(offsets[3], object.curve25519PkHex);
  writer.writeByteList(offsets[4], object.curve25519Sk);
  writer.writeString(offsets[5], object.curve25519SkHex);
  writer.writeLong(offsets[6], object.hashCode);
  writer.writeBool(offsets[7], object.isDefault);
  writer.writeString(offsets[8], object.mnemonic);
  writer.writeString(offsets[9], object.name);
  writer.writeString(offsets[10], object.note);
  writer.writeString(offsets[11], object.npub);
  writer.writeString(offsets[12], object.nsec);
  writer.writeString(offsets[13], object.secp256k1PKHex);
  writer.writeString(offsets[14], object.secp256k1SKHex);
  writer.writeBool(offsets[15], object.stringify);
  writer.writeLong(offsets[16], object.weight);
}

Identity _identityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Identity(
    curve25519Pk: reader.readByteList(offsets[2]) ?? [],
    curve25519PkHex: reader.readString(offsets[3]),
    curve25519Sk: reader.readByteList(offsets[4]) ?? [],
    curve25519SkHex: reader.readString(offsets[5]),
    mnemonic: reader.readString(offsets[8]),
    name: reader.readString(offsets[9]),
    note: reader.readStringOrNull(offsets[10]),
    npub: reader.readString(offsets[11]),
    nsec: reader.readString(offsets[12]),
    secp256k1PKHex: reader.readString(offsets[13]),
    secp256k1SKHex: reader.readString(offsets[14]),
  );
  object.about = reader.readStringOrNull(offsets[0]);
  object.createdAt = reader.readDateTime(offsets[1]);
  object.id = id;
  object.isDefault = reader.readBool(offsets[7]);
  object.weight = reader.readLong(offsets[16]);
  return object;
}

P _identityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readByteList(offset) ?? []) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readByteList(offset) ?? []) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readBool(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    case 13:
      return (reader.readString(offset)) as P;
    case 14:
      return (reader.readString(offset)) as P;
    case 15:
      return (reader.readBoolOrNull(offset)) as P;
    case 16:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _identityGetId(Identity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _identityGetLinks(Identity object) {
  return [];
}

void _identityAttach(IsarCollection<dynamic> col, Id id, Identity object) {
  object.id = id;
}

extension IdentityByIndex on IsarCollection<Identity> {
  Future<Identity?> getByCurve25519PkHex(String curve25519PkHex) {
    return getByIndex(r'curve25519PkHex', [curve25519PkHex]);
  }

  Identity? getByCurve25519PkHexSync(String curve25519PkHex) {
    return getByIndexSync(r'curve25519PkHex', [curve25519PkHex]);
  }

  Future<bool> deleteByCurve25519PkHex(String curve25519PkHex) {
    return deleteByIndex(r'curve25519PkHex', [curve25519PkHex]);
  }

  bool deleteByCurve25519PkHexSync(String curve25519PkHex) {
    return deleteByIndexSync(r'curve25519PkHex', [curve25519PkHex]);
  }

  Future<List<Identity?>> getAllByCurve25519PkHex(
      List<String> curve25519PkHexValues) {
    final values = curve25519PkHexValues.map((e) => [e]).toList();
    return getAllByIndex(r'curve25519PkHex', values);
  }

  List<Identity?> getAllByCurve25519PkHexSync(
      List<String> curve25519PkHexValues) {
    final values = curve25519PkHexValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'curve25519PkHex', values);
  }

  Future<int> deleteAllByCurve25519PkHex(List<String> curve25519PkHexValues) {
    final values = curve25519PkHexValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'curve25519PkHex', values);
  }

  int deleteAllByCurve25519PkHexSync(List<String> curve25519PkHexValues) {
    final values = curve25519PkHexValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'curve25519PkHex', values);
  }

  Future<Id> putByCurve25519PkHex(Identity object) {
    return putByIndex(r'curve25519PkHex', object);
  }

  Id putByCurve25519PkHexSync(Identity object, {bool saveLinks = true}) {
    return putByIndexSync(r'curve25519PkHex', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCurve25519PkHex(List<Identity> objects) {
    return putAllByIndex(r'curve25519PkHex', objects);
  }

  List<Id> putAllByCurve25519PkHexSync(List<Identity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'curve25519PkHex', objects, saveLinks: saveLinks);
  }
}

extension IdentityQueryWhereSort on QueryBuilder<Identity, Identity, QWhere> {
  QueryBuilder<Identity, Identity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension IdentityQueryWhere on QueryBuilder<Identity, Identity, QWhereClause> {
  QueryBuilder<Identity, Identity, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<Identity, Identity, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterWhereClause> idBetween(
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

  QueryBuilder<Identity, Identity, QAfterWhereClause> curve25519PkHexEqualTo(
      String curve25519PkHex) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'curve25519PkHex',
        value: [curve25519PkHex],
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterWhereClause> curve25519PkHexNotEqualTo(
      String curve25519PkHex) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'curve25519PkHex',
              lower: [],
              upper: [curve25519PkHex],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'curve25519PkHex',
              lower: [curve25519PkHex],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'curve25519PkHex',
              lower: [curve25519PkHex],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'curve25519PkHex',
              lower: [],
              upper: [curve25519PkHex],
              includeUpper: false,
            ));
      }
    });
  }
}

extension IdentityQueryFilter
    on QueryBuilder<Identity, Identity, QFilterCondition> {
  QueryBuilder<Identity, Identity, QAfterFilterCondition> aboutIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'about',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> aboutIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'about',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> aboutEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'about',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> aboutGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'about',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> aboutLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'about',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> aboutBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'about',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> aboutStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'about',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> aboutEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'about',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> aboutContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'about',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> aboutMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'about',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> aboutIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'about',
        value: '',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> aboutIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'about',
        value: '',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> createdAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> createdAtGreaterThan(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> createdAtLessThan(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> createdAtBetween(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519PkElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'curve25519Pk',
        value: value,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519PkElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'curve25519Pk',
        value: value,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519PkElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'curve25519Pk',
        value: value,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519PkElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'curve25519Pk',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519PkLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'curve25519Pk',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519PkIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'curve25519Pk',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519PkIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'curve25519Pk',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519PkLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'curve25519Pk',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519PkLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'curve25519Pk',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519PkLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'curve25519Pk',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519PkHexEqualTo(
    String value, {
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519PkHexGreaterThan(
    String value, {
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519PkHexLessThan(
    String value, {
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519PkHexBetween(
    String lower,
    String upper, {
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519PkHexStartsWith(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519PkHexEndsWith(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519PkHexContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'curve25519PkHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519PkHexMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'curve25519PkHex',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519PkHexIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'curve25519PkHex',
        value: '',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519PkHexIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'curve25519PkHex',
        value: '',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519SkElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'curve25519Sk',
        value: value,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519SkElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'curve25519Sk',
        value: value,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519SkElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'curve25519Sk',
        value: value,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519SkElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'curve25519Sk',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519SkLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'curve25519Sk',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519SkIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'curve25519Sk',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519SkIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'curve25519Sk',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519SkLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'curve25519Sk',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519SkLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'curve25519Sk',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519SkLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'curve25519Sk',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519SkHexEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'curve25519SkHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519SkHexGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'curve25519SkHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519SkHexLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'curve25519SkHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519SkHexBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'curve25519SkHex',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519SkHexStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'curve25519SkHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519SkHexEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'curve25519SkHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519SkHexContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'curve25519SkHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519SkHexMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'curve25519SkHex',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519SkHexIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'curve25519SkHex',
        value: '',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      curve25519SkHexIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'curve25519SkHex',
        value: '',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> hashCodeEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hashCode',
        value: value,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> hashCodeGreaterThan(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> hashCodeLessThan(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> hashCodeBetween(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> idBetween(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> isDefaultEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDefault',
        value: value,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> mnemonicEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mnemonic',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> mnemonicGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'mnemonic',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> mnemonicLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'mnemonic',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> mnemonicBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'mnemonic',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> mnemonicStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'mnemonic',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> mnemonicEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'mnemonic',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> mnemonicContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'mnemonic',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> mnemonicMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'mnemonic',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> mnemonicIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mnemonic',
        value: '',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> mnemonicIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'mnemonic',
        value: '',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> nameEqualTo(
    String value, {
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> nameGreaterThan(
    String value, {
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> nameLessThan(
    String value, {
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> nameStartsWith(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> nameEndsWith(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> nameContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> nameMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'name',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> noteIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'note',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> noteIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'note',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> noteEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> noteGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> noteLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> noteBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'note',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> noteStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> noteEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> noteContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> noteMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'note',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> noteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'note',
        value: '',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> noteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'note',
        value: '',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> npubEqualTo(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> npubGreaterThan(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> npubLessThan(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> npubBetween(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> npubStartsWith(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> npubEndsWith(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> npubContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'npub',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> npubMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'npub',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> npubIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'npub',
        value: '',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> npubIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'npub',
        value: '',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> nsecEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'nsec',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> nsecGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'nsec',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> nsecLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'nsec',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> nsecBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'nsec',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> nsecStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'nsec',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> nsecEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'nsec',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> nsecContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'nsec',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> nsecMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'nsec',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> nsecIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'nsec',
        value: '',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> nsecIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'nsec',
        value: '',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> secp256k1PKHexEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'secp256k1PKHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      secp256k1PKHexGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'secp256k1PKHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      secp256k1PKHexLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'secp256k1PKHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> secp256k1PKHexBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'secp256k1PKHex',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      secp256k1PKHexStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'secp256k1PKHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      secp256k1PKHexEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'secp256k1PKHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      secp256k1PKHexContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'secp256k1PKHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> secp256k1PKHexMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'secp256k1PKHex',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      secp256k1PKHexIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'secp256k1PKHex',
        value: '',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      secp256k1PKHexIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'secp256k1PKHex',
        value: '',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> secp256k1SKHexEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'secp256k1SKHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      secp256k1SKHexGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'secp256k1SKHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      secp256k1SKHexLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'secp256k1SKHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> secp256k1SKHexBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'secp256k1SKHex',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      secp256k1SKHexStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'secp256k1SKHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      secp256k1SKHexEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'secp256k1SKHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      secp256k1SKHexContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'secp256k1SKHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> secp256k1SKHexMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'secp256k1SKHex',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      secp256k1SKHexIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'secp256k1SKHex',
        value: '',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
      secp256k1SKHexIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'secp256k1SKHex',
        value: '',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> stringifyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'stringify',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> stringifyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'stringify',
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> stringifyEqualTo(
      bool? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'stringify',
        value: value,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> weightEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'weight',
        value: value,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> weightGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'weight',
        value: value,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> weightLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'weight',
        value: value,
      ));
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> weightBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'weight',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension IdentityQueryObject
    on QueryBuilder<Identity, Identity, QFilterCondition> {}

extension IdentityQueryLinks
    on QueryBuilder<Identity, Identity, QFilterCondition> {}

extension IdentityQuerySortBy on QueryBuilder<Identity, Identity, QSortBy> {
  QueryBuilder<Identity, Identity, QAfterSortBy> sortByAbout() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'about', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByAboutDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'about', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByCurve25519PkHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'curve25519PkHex', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByCurve25519PkHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'curve25519PkHex', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByCurve25519SkHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'curve25519SkHex', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByCurve25519SkHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'curve25519SkHex', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByIsDefault() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDefault', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByIsDefaultDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDefault', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByMnemonic() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mnemonic', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByMnemonicDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mnemonic', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByNpub() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'npub', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByNpubDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'npub', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByNsec() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nsec', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByNsecDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nsec', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortBySecp256k1PKHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'secp256k1PKHex', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortBySecp256k1PKHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'secp256k1PKHex', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortBySecp256k1SKHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'secp256k1SKHex', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortBySecp256k1SKHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'secp256k1SKHex', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByStringifyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByWeight() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'weight', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByWeightDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'weight', Sort.desc);
    });
  }
}

extension IdentityQuerySortThenBy
    on QueryBuilder<Identity, Identity, QSortThenBy> {
  QueryBuilder<Identity, Identity, QAfterSortBy> thenByAbout() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'about', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByAboutDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'about', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByCurve25519PkHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'curve25519PkHex', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByCurve25519PkHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'curve25519PkHex', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByCurve25519SkHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'curve25519SkHex', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByCurve25519SkHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'curve25519SkHex', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByIsDefault() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDefault', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByIsDefaultDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDefault', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByMnemonic() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mnemonic', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByMnemonicDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mnemonic', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByNpub() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'npub', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByNpubDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'npub', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByNsec() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nsec', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByNsecDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nsec', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenBySecp256k1PKHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'secp256k1PKHex', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenBySecp256k1PKHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'secp256k1PKHex', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenBySecp256k1SKHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'secp256k1SKHex', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenBySecp256k1SKHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'secp256k1SKHex', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByStringifyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByWeight() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'weight', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByWeightDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'weight', Sort.desc);
    });
  }
}

extension IdentityQueryWhereDistinct
    on QueryBuilder<Identity, Identity, QDistinct> {
  QueryBuilder<Identity, Identity, QDistinct> distinctByAbout(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'about', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Identity, Identity, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<Identity, Identity, QDistinct> distinctByCurve25519Pk() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'curve25519Pk');
    });
  }

  QueryBuilder<Identity, Identity, QDistinct> distinctByCurve25519PkHex(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'curve25519PkHex',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Identity, Identity, QDistinct> distinctByCurve25519Sk() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'curve25519Sk');
    });
  }

  QueryBuilder<Identity, Identity, QDistinct> distinctByCurve25519SkHex(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'curve25519SkHex',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Identity, Identity, QDistinct> distinctByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hashCode');
    });
  }

  QueryBuilder<Identity, Identity, QDistinct> distinctByIsDefault() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDefault');
    });
  }

  QueryBuilder<Identity, Identity, QDistinct> distinctByMnemonic(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mnemonic', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Identity, Identity, QDistinct> distinctByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Identity, Identity, QDistinct> distinctByNote(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'note', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Identity, Identity, QDistinct> distinctByNpub(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'npub', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Identity, Identity, QDistinct> distinctByNsec(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nsec', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Identity, Identity, QDistinct> distinctBySecp256k1PKHex(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'secp256k1PKHex',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Identity, Identity, QDistinct> distinctBySecp256k1SKHex(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'secp256k1SKHex',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Identity, Identity, QDistinct> distinctByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'stringify');
    });
  }

  QueryBuilder<Identity, Identity, QDistinct> distinctByWeight() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'weight');
    });
  }
}

extension IdentityQueryProperty
    on QueryBuilder<Identity, Identity, QQueryProperty> {
  QueryBuilder<Identity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Identity, String?, QQueryOperations> aboutProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'about');
    });
  }

  QueryBuilder<Identity, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<Identity, List<int>, QQueryOperations> curve25519PkProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'curve25519Pk');
    });
  }

  QueryBuilder<Identity, String, QQueryOperations> curve25519PkHexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'curve25519PkHex');
    });
  }

  QueryBuilder<Identity, List<int>, QQueryOperations> curve25519SkProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'curve25519Sk');
    });
  }

  QueryBuilder<Identity, String, QQueryOperations> curve25519SkHexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'curve25519SkHex');
    });
  }

  QueryBuilder<Identity, int, QQueryOperations> hashCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hashCode');
    });
  }

  QueryBuilder<Identity, bool, QQueryOperations> isDefaultProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDefault');
    });
  }

  QueryBuilder<Identity, String, QQueryOperations> mnemonicProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mnemonic');
    });
  }

  QueryBuilder<Identity, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<Identity, String?, QQueryOperations> noteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'note');
    });
  }

  QueryBuilder<Identity, String, QQueryOperations> npubProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'npub');
    });
  }

  QueryBuilder<Identity, String, QQueryOperations> nsecProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nsec');
    });
  }

  QueryBuilder<Identity, String, QQueryOperations> secp256k1PKHexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'secp256k1PKHex');
    });
  }

  QueryBuilder<Identity, String, QQueryOperations> secp256k1SKHexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'secp256k1SKHex');
    });
  }

  QueryBuilder<Identity, bool?, QQueryOperations> stringifyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stringify');
    });
  }

  QueryBuilder<Identity, int, QQueryOperations> weightProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'weight');
    });
  }
}

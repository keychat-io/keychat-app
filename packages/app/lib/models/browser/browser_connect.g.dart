// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'browser_connect.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetBrowserConnectCollection on Isar {
  IsarCollection<BrowserConnect> get browserConnects => this.collection();
}

const BrowserConnectSchema = CollectionSchema(
  name: r'BrowserConnect',
  id: 4080801284154222591,
  properties: {
    r'autoLogin': PropertySchema(
      id: 0,
      name: r'autoLogin',
      type: IsarType.bool,
    ),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'favicon': PropertySchema(
      id: 2,
      name: r'favicon',
      type: IsarType.string,
    ),
    r'hashCode': PropertySchema(
      id: 3,
      name: r'hashCode',
      type: IsarType.long,
    ),
    r'host': PropertySchema(
      id: 4,
      name: r'host',
      type: IsarType.string,
    ),
    r'pubkey': PropertySchema(
      id: 5,
      name: r'pubkey',
      type: IsarType.string,
    ),
    r'stringify': PropertySchema(
      id: 6,
      name: r'stringify',
      type: IsarType.bool,
    )
  },
  estimateSize: _browserConnectEstimateSize,
  serialize: _browserConnectSerialize,
  deserialize: _browserConnectDeserialize,
  deserializeProp: _browserConnectDeserializeProp,
  idName: r'id',
  indexes: {
    r'host': IndexSchema(
      id: -7602099240340412494,
      name: r'host',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'host',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _browserConnectGetId,
  getLinks: _browserConnectGetLinks,
  attach: _browserConnectAttach,
  version: '3.2.0-dev.2',
);

int _browserConnectEstimateSize(
  BrowserConnect object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.favicon;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.host.length * 3;
  bytesCount += 3 + object.pubkey.length * 3;
  return bytesCount;
}

void _browserConnectSerialize(
  BrowserConnect object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeBool(offsets[0], object.autoLogin);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeString(offsets[2], object.favicon);
  writer.writeLong(offsets[3], object.hashCode);
  writer.writeString(offsets[4], object.host);
  writer.writeString(offsets[5], object.pubkey);
  writer.writeBool(offsets[6], object.stringify);
}

BrowserConnect _browserConnectDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = BrowserConnect(
    favicon: reader.readStringOrNull(offsets[2]),
    host: reader.readString(offsets[4]),
    pubkey: reader.readString(offsets[5]),
  );
  object.autoLogin = reader.readBool(offsets[0]);
  object.createdAt = reader.readDateTime(offsets[1]);
  object.id = id;
  return object;
}

P _browserConnectDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readBool(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readBoolOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _browserConnectGetId(BrowserConnect object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _browserConnectGetLinks(BrowserConnect object) {
  return [];
}

void _browserConnectAttach(
    IsarCollection<dynamic> col, Id id, BrowserConnect object) {
  object.id = id;
}

extension BrowserConnectByIndex on IsarCollection<BrowserConnect> {
  Future<BrowserConnect?> getByHost(String host) {
    return getByIndex(r'host', [host]);
  }

  BrowserConnect? getByHostSync(String host) {
    return getByIndexSync(r'host', [host]);
  }

  Future<bool> deleteByHost(String host) {
    return deleteByIndex(r'host', [host]);
  }

  bool deleteByHostSync(String host) {
    return deleteByIndexSync(r'host', [host]);
  }

  Future<List<BrowserConnect?>> getAllByHost(List<String> hostValues) {
    final values = hostValues.map((e) => [e]).toList();
    return getAllByIndex(r'host', values);
  }

  List<BrowserConnect?> getAllByHostSync(List<String> hostValues) {
    final values = hostValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'host', values);
  }

  Future<int> deleteAllByHost(List<String> hostValues) {
    final values = hostValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'host', values);
  }

  int deleteAllByHostSync(List<String> hostValues) {
    final values = hostValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'host', values);
  }

  Future<Id> putByHost(BrowserConnect object) {
    return putByIndex(r'host', object);
  }

  Id putByHostSync(BrowserConnect object, {bool saveLinks = true}) {
    return putByIndexSync(r'host', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByHost(List<BrowserConnect> objects) {
    return putAllByIndex(r'host', objects);
  }

  List<Id> putAllByHostSync(List<BrowserConnect> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'host', objects, saveLinks: saveLinks);
  }
}

extension BrowserConnectQueryWhereSort
    on QueryBuilder<BrowserConnect, BrowserConnect, QWhere> {
  QueryBuilder<BrowserConnect, BrowserConnect, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension BrowserConnectQueryWhere
    on QueryBuilder<BrowserConnect, BrowserConnect, QWhereClause> {
  QueryBuilder<BrowserConnect, BrowserConnect, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterWhereClause> idNotEqualTo(
      Id id) {
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

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterWhereClause> idBetween(
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

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterWhereClause> hostEqualTo(
      String host) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'host',
        value: [host],
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterWhereClause>
      hostNotEqualTo(String host) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'host',
              lower: [],
              upper: [host],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'host',
              lower: [host],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'host',
              lower: [host],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'host',
              lower: [],
              upper: [host],
              includeUpper: false,
            ));
      }
    });
  }
}

extension BrowserConnectQueryFilter
    on QueryBuilder<BrowserConnect, BrowserConnect, QFilterCondition> {
  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      autoLoginEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'autoLogin',
        value: value,
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      createdAtGreaterThan(
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

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      createdAtLessThan(
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

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      createdAtBetween(
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

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      faviconIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'favicon',
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      faviconIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'favicon',
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      faviconEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'favicon',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      faviconGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'favicon',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      faviconLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'favicon',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      faviconBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'favicon',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      faviconStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'favicon',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      faviconEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'favicon',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      faviconContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'favicon',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      faviconMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'favicon',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      faviconIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'favicon',
        value: '',
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      faviconIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'favicon',
        value: '',
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      hashCodeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hashCode',
        value: value,
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      hashCodeGreaterThan(
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

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      hashCodeLessThan(
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

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      hashCodeBetween(
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

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      hostEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'host',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      hostGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'host',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      hostLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'host',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      hostBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'host',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      hostStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'host',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      hostEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'host',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      hostContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'host',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      hostMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'host',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      hostIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'host',
        value: '',
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      hostIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'host',
        value: '',
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      idGreaterThan(
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

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      idLessThan(
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

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition> idBetween(
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

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      pubkeyEqualTo(
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

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      pubkeyGreaterThan(
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

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      pubkeyLessThan(
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

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      pubkeyBetween(
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

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      pubkeyStartsWith(
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

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      pubkeyEndsWith(
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

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      pubkeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'pubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      pubkeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'pubkey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      pubkeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pubkey',
        value: '',
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      pubkeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'pubkey',
        value: '',
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      stringifyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'stringify',
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      stringifyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'stringify',
      ));
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterFilterCondition>
      stringifyEqualTo(bool? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'stringify',
        value: value,
      ));
    });
  }
}

extension BrowserConnectQueryObject
    on QueryBuilder<BrowserConnect, BrowserConnect, QFilterCondition> {}

extension BrowserConnectQueryLinks
    on QueryBuilder<BrowserConnect, BrowserConnect, QFilterCondition> {}

extension BrowserConnectQuerySortBy
    on QueryBuilder<BrowserConnect, BrowserConnect, QSortBy> {
  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy> sortByAutoLogin() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoLogin', Sort.asc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy>
      sortByAutoLoginDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoLogin', Sort.desc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy> sortByFavicon() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'favicon', Sort.asc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy>
      sortByFaviconDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'favicon', Sort.desc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy> sortByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy>
      sortByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy> sortByHost() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'host', Sort.asc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy> sortByHostDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'host', Sort.desc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy> sortByPubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pubkey', Sort.asc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy>
      sortByPubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pubkey', Sort.desc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy> sortByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.asc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy>
      sortByStringifyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.desc);
    });
  }
}

extension BrowserConnectQuerySortThenBy
    on QueryBuilder<BrowserConnect, BrowserConnect, QSortThenBy> {
  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy> thenByAutoLogin() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoLogin', Sort.asc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy>
      thenByAutoLoginDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoLogin', Sort.desc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy> thenByFavicon() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'favicon', Sort.asc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy>
      thenByFaviconDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'favicon', Sort.desc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy> thenByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy>
      thenByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy> thenByHost() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'host', Sort.asc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy> thenByHostDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'host', Sort.desc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy> thenByPubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pubkey', Sort.asc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy>
      thenByPubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pubkey', Sort.desc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy> thenByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.asc);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QAfterSortBy>
      thenByStringifyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.desc);
    });
  }
}

extension BrowserConnectQueryWhereDistinct
    on QueryBuilder<BrowserConnect, BrowserConnect, QDistinct> {
  QueryBuilder<BrowserConnect, BrowserConnect, QDistinct>
      distinctByAutoLogin() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'autoLogin');
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QDistinct> distinctByFavicon(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'favicon', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QDistinct> distinctByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hashCode');
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QDistinct> distinctByHost(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'host', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QDistinct> distinctByPubkey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pubkey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BrowserConnect, BrowserConnect, QDistinct>
      distinctByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'stringify');
    });
  }
}

extension BrowserConnectQueryProperty
    on QueryBuilder<BrowserConnect, BrowserConnect, QQueryProperty> {
  QueryBuilder<BrowserConnect, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<BrowserConnect, bool, QQueryOperations> autoLoginProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'autoLogin');
    });
  }

  QueryBuilder<BrowserConnect, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<BrowserConnect, String?, QQueryOperations> faviconProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'favicon');
    });
  }

  QueryBuilder<BrowserConnect, int, QQueryOperations> hashCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hashCode');
    });
  }

  QueryBuilder<BrowserConnect, String, QQueryOperations> hostProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'host');
    });
  }

  QueryBuilder<BrowserConnect, String, QQueryOperations> pubkeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pubkey');
    });
  }

  QueryBuilder<BrowserConnect, bool?, QQueryOperations> stringifyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stringify');
    });
  }
}

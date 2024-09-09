// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nostr_event_status.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetNostrEventStatusCollection on Isar {
  IsarCollection<NostrEventStatus> get nostrEventStatus => this.collection();
}

const NostrEventStatusSchema = CollectionSchema(
  name: r'NostrEventStatus',
  id: 2589846592525476802,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'ecashAmount': PropertySchema(
      id: 1,
      name: r'ecashAmount',
      type: IsarType.double,
    ),
    r'ecashMint': PropertySchema(
      id: 2,
      name: r'ecashMint',
      type: IsarType.string,
    ),
    r'ecashName': PropertySchema(
      id: 3,
      name: r'ecashName',
      type: IsarType.string,
    ),
    r'ecashToken': PropertySchema(
      id: 4,
      name: r'ecashToken',
      type: IsarType.string,
    ),
    r'error': PropertySchema(
      id: 5,
      name: r'error',
      type: IsarType.string,
    ),
    r'eventId': PropertySchema(
      id: 6,
      name: r'eventId',
      type: IsarType.string,
    ),
    r'hashCode': PropertySchema(
      id: 7,
      name: r'hashCode',
      type: IsarType.long,
    ),
    r'isReceive': PropertySchema(
      id: 8,
      name: r'isReceive',
      type: IsarType.bool,
    ),
    r'receiveSnapshot': PropertySchema(
      id: 9,
      name: r'receiveSnapshot',
      type: IsarType.string,
    ),
    r'relay': PropertySchema(
      id: 10,
      name: r'relay',
      type: IsarType.string,
    ),
    r'resCode': PropertySchema(
      id: 11,
      name: r'resCode',
      type: IsarType.long,
    ),
    r'roomId': PropertySchema(
      id: 12,
      name: r'roomId',
      type: IsarType.long,
    ),
    r'sendStatus': PropertySchema(
      id: 13,
      name: r'sendStatus',
      type: IsarType.int,
      enumMap: _NostrEventStatussendStatusEnumValueMap,
    ),
    r'stringify': PropertySchema(
      id: 14,
      name: r'stringify',
      type: IsarType.bool,
    ),
    r'updatedAt': PropertySchema(
      id: 15,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'version': PropertySchema(
      id: 16,
      name: r'version',
      type: IsarType.long,
    )
  },
  estimateSize: _nostrEventStatusEstimateSize,
  serialize: _nostrEventStatusSerialize,
  deserialize: _nostrEventStatusDeserialize,
  deserializeProp: _nostrEventStatusDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _nostrEventStatusGetId,
  getLinks: _nostrEventStatusGetLinks,
  attach: _nostrEventStatusAttach,
  version: '3.1.0+1',
);

int _nostrEventStatusEstimateSize(
  NostrEventStatus object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.ecashMint;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.ecashName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.ecashToken;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.error;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.eventId.length * 3;
  {
    final value = object.receiveSnapshot;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.relay.length * 3;
  return bytesCount;
}

void _nostrEventStatusSerialize(
  NostrEventStatus object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeDouble(offsets[1], object.ecashAmount);
  writer.writeString(offsets[2], object.ecashMint);
  writer.writeString(offsets[3], object.ecashName);
  writer.writeString(offsets[4], object.ecashToken);
  writer.writeString(offsets[5], object.error);
  writer.writeString(offsets[6], object.eventId);
  writer.writeLong(offsets[7], object.hashCode);
  writer.writeBool(offsets[8], object.isReceive);
  writer.writeString(offsets[9], object.receiveSnapshot);
  writer.writeString(offsets[10], object.relay);
  writer.writeLong(offsets[11], object.resCode);
  writer.writeLong(offsets[12], object.roomId);
  writer.writeInt(offsets[13], object.sendStatus.index);
  writer.writeBool(offsets[14], object.stringify);
  writer.writeDateTime(offsets[15], object.updatedAt);
  writer.writeLong(offsets[16], object.version);
}

NostrEventStatus _nostrEventStatusDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = NostrEventStatus(
    eventId: reader.readString(offsets[6]),
    relay: reader.readString(offsets[10]),
    roomId: reader.readLong(offsets[12]),
    sendStatus: _NostrEventStatussendStatusValueEnumMap[
            reader.readIntOrNull(offsets[13])] ??
        EventSendEnum.init,
  );
  object.createdAt = reader.readDateTime(offsets[0]);
  object.ecashAmount = reader.readDouble(offsets[1]);
  object.ecashMint = reader.readStringOrNull(offsets[2]);
  object.ecashName = reader.readStringOrNull(offsets[3]);
  object.ecashToken = reader.readStringOrNull(offsets[4]);
  object.error = reader.readStringOrNull(offsets[5]);
  object.id = id;
  object.isReceive = reader.readBool(offsets[8]);
  object.receiveSnapshot = reader.readStringOrNull(offsets[9]);
  object.resCode = reader.readLong(offsets[11]);
  object.updatedAt = reader.readDateTime(offsets[15]);
  object.version = reader.readLong(offsets[16]);
  return object;
}

P _nostrEventStatusDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readDouble(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readLong(offset)) as P;
    case 8:
      return (reader.readBool(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readLong(offset)) as P;
    case 12:
      return (reader.readLong(offset)) as P;
    case 13:
      return (_NostrEventStatussendStatusValueEnumMap[
              reader.readIntOrNull(offset)] ??
          EventSendEnum.init) as P;
    case 14:
      return (reader.readBoolOrNull(offset)) as P;
    case 15:
      return (reader.readDateTime(offset)) as P;
    case 16:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _NostrEventStatussendStatusEnumValueMap = {
  'init': 0,
  'noAcitveRelay': 1,
  'relayConnecting': 2,
  'relayDisconnected': 3,
  'cashuError': 4,
  'serverReturnFailed': 5,
  'proccessError': 6,
  'success': 7,
};
const _NostrEventStatussendStatusValueEnumMap = {
  0: EventSendEnum.init,
  1: EventSendEnum.noAcitveRelay,
  2: EventSendEnum.relayConnecting,
  3: EventSendEnum.relayDisconnected,
  4: EventSendEnum.cashuError,
  5: EventSendEnum.serverReturnFailed,
  6: EventSendEnum.proccessError,
  7: EventSendEnum.success,
};

Id _nostrEventStatusGetId(NostrEventStatus object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _nostrEventStatusGetLinks(NostrEventStatus object) {
  return [];
}

void _nostrEventStatusAttach(
    IsarCollection<dynamic> col, Id id, NostrEventStatus object) {
  object.id = id;
}

extension NostrEventStatusQueryWhereSort
    on QueryBuilder<NostrEventStatus, NostrEventStatus, QWhere> {
  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension NostrEventStatusQueryWhere
    on QueryBuilder<NostrEventStatus, NostrEventStatus, QWhereClause> {
  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterWhereClause>
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

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterWhereClause> idBetween(
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
}

extension NostrEventStatusQueryFilter
    on QueryBuilder<NostrEventStatus, NostrEventStatus, QFilterCondition> {
  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
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

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
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

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
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

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashAmountEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ecashAmount',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashAmountGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ecashAmount',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashAmountLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ecashAmount',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashAmountBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ecashAmount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashMintIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'ecashMint',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashMintIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'ecashMint',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashMintEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ecashMint',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashMintGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ecashMint',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashMintLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ecashMint',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashMintBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ecashMint',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashMintStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'ecashMint',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashMintEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'ecashMint',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashMintContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'ecashMint',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashMintMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'ecashMint',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashMintIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ecashMint',
        value: '',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashMintIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'ecashMint',
        value: '',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'ecashName',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'ecashName',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ecashName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ecashName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ecashName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ecashName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'ecashName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'ecashName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'ecashName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'ecashName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ecashName',
        value: '',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'ecashName',
        value: '',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashTokenIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'ecashToken',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashTokenIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'ecashToken',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashTokenEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ecashToken',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashTokenGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ecashToken',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashTokenLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ecashToken',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashTokenBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ecashToken',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashTokenStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'ecashToken',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashTokenEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'ecashToken',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashTokenContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'ecashToken',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashTokenMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'ecashToken',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashTokenIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ecashToken',
        value: '',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      ecashTokenIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'ecashToken',
        value: '',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      errorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'error',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      errorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'error',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      errorEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'error',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      errorGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'error',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      errorLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'error',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      errorBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'error',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      errorStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'error',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      errorEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'error',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      errorContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'error',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      errorMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'error',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      errorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'error',
        value: '',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      errorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'error',
        value: '',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      eventIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'eventId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      eventIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'eventId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      eventIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'eventId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      eventIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'eventId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      eventIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'eventId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      eventIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'eventId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      eventIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'eventId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      eventIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'eventId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      eventIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'eventId',
        value: '',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      eventIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'eventId',
        value: '',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      hashCodeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hashCode',
        value: value,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
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

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
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

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
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

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
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

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
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

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      idBetween(
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

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      isReceiveEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isReceive',
        value: value,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      receiveSnapshotIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'receiveSnapshot',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      receiveSnapshotIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'receiveSnapshot',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      receiveSnapshotEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'receiveSnapshot',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      receiveSnapshotGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'receiveSnapshot',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      receiveSnapshotLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'receiveSnapshot',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      receiveSnapshotBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'receiveSnapshot',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      receiveSnapshotStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'receiveSnapshot',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      receiveSnapshotEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'receiveSnapshot',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      receiveSnapshotContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'receiveSnapshot',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      receiveSnapshotMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'receiveSnapshot',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      receiveSnapshotIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'receiveSnapshot',
        value: '',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      receiveSnapshotIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'receiveSnapshot',
        value: '',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      relayEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'relay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      relayGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'relay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      relayLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'relay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      relayBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'relay',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      relayStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'relay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      relayEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'relay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      relayContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'relay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      relayMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'relay',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      relayIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'relay',
        value: '',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      relayIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'relay',
        value: '',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      resCodeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resCode',
        value: value,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      resCodeGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'resCode',
        value: value,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      resCodeLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'resCode',
        value: value,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      resCodeBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'resCode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      roomIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'roomId',
        value: value,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      roomIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'roomId',
        value: value,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      roomIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'roomId',
        value: value,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      roomIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'roomId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      sendStatusEqualTo(EventSendEnum value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sendStatus',
        value: value,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      sendStatusGreaterThan(
    EventSendEnum value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sendStatus',
        value: value,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      sendStatusLessThan(
    EventSendEnum value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sendStatus',
        value: value,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      sendStatusBetween(
    EventSendEnum lower,
    EventSendEnum upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sendStatus',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      stringifyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'stringify',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      stringifyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'stringify',
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      stringifyEqualTo(bool? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'stringify',
        value: value,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      updatedAtGreaterThan(
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

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      updatedAtLessThan(
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

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      updatedAtBetween(
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

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      versionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      versionGreaterThan(
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

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      versionLessThan(
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

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterFilterCondition>
      versionBetween(
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

extension NostrEventStatusQueryObject
    on QueryBuilder<NostrEventStatus, NostrEventStatus, QFilterCondition> {}

extension NostrEventStatusQueryLinks
    on QueryBuilder<NostrEventStatus, NostrEventStatus, QFilterCondition> {}

extension NostrEventStatusQuerySortBy
    on QueryBuilder<NostrEventStatus, NostrEventStatus, QSortBy> {
  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByEcashAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ecashAmount', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByEcashAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ecashAmount', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByEcashMint() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ecashMint', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByEcashMintDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ecashMint', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByEcashName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ecashName', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByEcashNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ecashName', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByEcashToken() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ecashToken', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByEcashTokenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ecashToken', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy> sortByError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'error', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'error', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByEventId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventId', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByEventIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventId', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByIsReceive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isReceive', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByIsReceiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isReceive', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByReceiveSnapshot() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiveSnapshot', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByReceiveSnapshotDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiveSnapshot', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy> sortByRelay() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'relay', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByRelayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'relay', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByResCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resCode', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByResCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resCode', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByRoomId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roomId', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByRoomIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roomId', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortBySendStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sendStatus', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortBySendStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sendStatus', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByStringifyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension NostrEventStatusQuerySortThenBy
    on QueryBuilder<NostrEventStatus, NostrEventStatus, QSortThenBy> {
  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByEcashAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ecashAmount', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByEcashAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ecashAmount', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByEcashMint() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ecashMint', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByEcashMintDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ecashMint', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByEcashName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ecashName', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByEcashNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ecashName', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByEcashToken() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ecashToken', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByEcashTokenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ecashToken', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy> thenByError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'error', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'error', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByEventId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventId', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByEventIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventId', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByIsReceive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isReceive', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByIsReceiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isReceive', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByReceiveSnapshot() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiveSnapshot', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByReceiveSnapshotDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiveSnapshot', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy> thenByRelay() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'relay', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByRelayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'relay', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByResCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resCode', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByResCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resCode', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByRoomId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roomId', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByRoomIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roomId', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenBySendStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sendStatus', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenBySendStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sendStatus', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByStringifyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QAfterSortBy>
      thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension NostrEventStatusQueryWhereDistinct
    on QueryBuilder<NostrEventStatus, NostrEventStatus, QDistinct> {
  QueryBuilder<NostrEventStatus, NostrEventStatus, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QDistinct>
      distinctByEcashAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ecashAmount');
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QDistinct>
      distinctByEcashMint({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ecashMint', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QDistinct>
      distinctByEcashName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ecashName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QDistinct>
      distinctByEcashToken({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ecashToken', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QDistinct> distinctByError(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'error', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QDistinct> distinctByEventId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'eventId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QDistinct>
      distinctByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hashCode');
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QDistinct>
      distinctByIsReceive() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isReceive');
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QDistinct>
      distinctByReceiveSnapshot({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'receiveSnapshot',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QDistinct> distinctByRelay(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'relay', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QDistinct>
      distinctByResCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resCode');
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QDistinct>
      distinctByRoomId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'roomId');
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QDistinct>
      distinctBySendStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sendStatus');
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QDistinct>
      distinctByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'stringify');
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<NostrEventStatus, NostrEventStatus, QDistinct>
      distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version');
    });
  }
}

extension NostrEventStatusQueryProperty
    on QueryBuilder<NostrEventStatus, NostrEventStatus, QQueryProperty> {
  QueryBuilder<NostrEventStatus, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<NostrEventStatus, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<NostrEventStatus, double, QQueryOperations>
      ecashAmountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ecashAmount');
    });
  }

  QueryBuilder<NostrEventStatus, String?, QQueryOperations>
      ecashMintProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ecashMint');
    });
  }

  QueryBuilder<NostrEventStatus, String?, QQueryOperations>
      ecashNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ecashName');
    });
  }

  QueryBuilder<NostrEventStatus, String?, QQueryOperations>
      ecashTokenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ecashToken');
    });
  }

  QueryBuilder<NostrEventStatus, String?, QQueryOperations> errorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'error');
    });
  }

  QueryBuilder<NostrEventStatus, String, QQueryOperations> eventIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'eventId');
    });
  }

  QueryBuilder<NostrEventStatus, int, QQueryOperations> hashCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hashCode');
    });
  }

  QueryBuilder<NostrEventStatus, bool, QQueryOperations> isReceiveProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isReceive');
    });
  }

  QueryBuilder<NostrEventStatus, String?, QQueryOperations>
      receiveSnapshotProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'receiveSnapshot');
    });
  }

  QueryBuilder<NostrEventStatus, String, QQueryOperations> relayProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'relay');
    });
  }

  QueryBuilder<NostrEventStatus, int, QQueryOperations> resCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resCode');
    });
  }

  QueryBuilder<NostrEventStatus, int, QQueryOperations> roomIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'roomId');
    });
  }

  QueryBuilder<NostrEventStatus, EventSendEnum, QQueryOperations>
      sendStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sendStatus');
    });
  }

  QueryBuilder<NostrEventStatus, bool?, QQueryOperations> stringifyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stringify');
    });
  }

  QueryBuilder<NostrEventStatus, DateTime, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<NostrEventStatus, int, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }
}

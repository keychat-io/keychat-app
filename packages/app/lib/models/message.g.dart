// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMessageCollection on Isar {
  IsarCollection<Message> get messages => this.collection();
}

const MessageSchema = CollectionSchema(
  name: r'Message',
  id: 2463283977299753079,
  properties: {
    r'cashuInfo': PropertySchema(
      id: 0,
      name: r'cashuInfo',
      type: IsarType.object,
      target: r'CashuInfoModel',
    ),
    r'confirmResult': PropertySchema(
      id: 1,
      name: r'confirmResult',
      type: IsarType.string,
    ),
    r'content': PropertySchema(
      id: 2,
      name: r'content',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 3,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'encryptType': PropertySchema(
      id: 4,
      name: r'encryptType',
      type: IsarType.int,
      enumMap: _MessageencryptTypeEnumValueMap,
    ),
    r'eventIds': PropertySchema(
      id: 5,
      name: r'eventIds',
      type: IsarType.stringList,
    ),
    r'from': PropertySchema(
      id: 6,
      name: r'from',
      type: IsarType.string,
    ),
    r'hashCode': PropertySchema(
      id: 7,
      name: r'hashCode',
      type: IsarType.long,
    ),
    r'idPubkey': PropertySchema(
      id: 8,
      name: r'idPubkey',
      type: IsarType.string,
    ),
    r'identityId': PropertySchema(
      id: 9,
      name: r'identityId',
      type: IsarType.long,
    ),
    r'isMeSend': PropertySchema(
      id: 10,
      name: r'isMeSend',
      type: IsarType.bool,
    ),
    r'isRead': PropertySchema(
      id: 11,
      name: r'isRead',
      type: IsarType.bool,
    ),
    r'isSystem': PropertySchema(
      id: 12,
      name: r'isSystem',
      type: IsarType.bool,
    ),
    r'mediaType': PropertySchema(
      id: 13,
      name: r'mediaType',
      type: IsarType.int,
      enumMap: _MessagemediaTypeEnumValueMap,
    ),
    r'msgKeyHash': PropertySchema(
      id: 14,
      name: r'msgKeyHash',
      type: IsarType.string,
    ),
    r'msgid': PropertySchema(
      id: 15,
      name: r'msgid',
      type: IsarType.string,
    ),
    r'rawEvents': PropertySchema(
      id: 16,
      name: r'rawEvents',
      type: IsarType.stringList,
    ),
    r'realMessage': PropertySchema(
      id: 17,
      name: r'realMessage',
      type: IsarType.string,
    ),
    r'receiveAt': PropertySchema(
      id: 18,
      name: r'receiveAt',
      type: IsarType.dateTime,
    ),
    r'reply': PropertySchema(
      id: 19,
      name: r'reply',
      type: IsarType.object,
      target: r'MsgReply',
    ),
    r'requestConfrim': PropertySchema(
      id: 20,
      name: r'requestConfrim',
      type: IsarType.int,
      enumMap: _MessagerequestConfrimEnumValueMap,
    ),
    r'roomId': PropertySchema(
      id: 21,
      name: r'roomId',
      type: IsarType.long,
    ),
    r'sent': PropertySchema(
      id: 22,
      name: r'sent',
      type: IsarType.int,
      enumMap: _MessagesentEnumValueMap,
    ),
    r'stringify': PropertySchema(
      id: 23,
      name: r'stringify',
      type: IsarType.bool,
    ),
    r'subEvent': PropertySchema(
      id: 24,
      name: r'subEvent',
      type: IsarType.string,
    ),
    r'to': PropertySchema(
      id: 25,
      name: r'to',
      type: IsarType.string,
    )
  },
  estimateSize: _messageEstimateSize,
  serialize: _messageSerialize,
  deserialize: _messageDeserialize,
  deserializeProp: _messageDeserializeProp,
  idName: r'id',
  indexes: {
    r'msgid_identityId': IndexSchema(
      id: -5610396770668586251,
      name: r'msgid_identityId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'msgid',
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
  embeddedSchemas: {
    r'MsgReply': MsgReplySchema,
    r'CashuInfoModel': CashuInfoModelSchema
  },
  getId: _messageGetId,
  getLinks: _messageGetLinks,
  attach: _messageAttach,
  version: '3.1.0+1',
);

int _messageEstimateSize(
  Message object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.cashuInfo;
    if (value != null) {
      bytesCount += 3 +
          CashuInfoModelSchema.estimateSize(
              value, allOffsets[CashuInfoModel]!, allOffsets);
    }
  }
  {
    final value = object.confirmResult;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.content.length * 3;
  bytesCount += 3 + object.eventIds.length * 3;
  {
    for (var i = 0; i < object.eventIds.length; i++) {
      final value = object.eventIds[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.from.length * 3;
  bytesCount += 3 + object.idPubkey.length * 3;
  {
    final value = object.msgKeyHash;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.msgid.length * 3;
  bytesCount += 3 + object.rawEvents.length * 3;
  {
    for (var i = 0; i < object.rawEvents.length; i++) {
      final value = object.rawEvents[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.realMessage;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.reply;
    if (value != null) {
      bytesCount += 3 +
          MsgReplySchema.estimateSize(value, allOffsets[MsgReply]!, allOffsets);
    }
  }
  {
    final value = object.subEvent;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.to.length * 3;
  return bytesCount;
}

void _messageSerialize(
  Message object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeObject<CashuInfoModel>(
    offsets[0],
    allOffsets,
    CashuInfoModelSchema.serialize,
    object.cashuInfo,
  );
  writer.writeString(offsets[1], object.confirmResult);
  writer.writeString(offsets[2], object.content);
  writer.writeDateTime(offsets[3], object.createdAt);
  writer.writeInt(offsets[4], object.encryptType.index);
  writer.writeStringList(offsets[5], object.eventIds);
  writer.writeString(offsets[6], object.from);
  writer.writeLong(offsets[7], object.hashCode);
  writer.writeString(offsets[8], object.idPubkey);
  writer.writeLong(offsets[9], object.identityId);
  writer.writeBool(offsets[10], object.isMeSend);
  writer.writeBool(offsets[11], object.isRead);
  writer.writeBool(offsets[12], object.isSystem);
  writer.writeInt(offsets[13], object.mediaType.index);
  writer.writeString(offsets[14], object.msgKeyHash);
  writer.writeString(offsets[15], object.msgid);
  writer.writeStringList(offsets[16], object.rawEvents);
  writer.writeString(offsets[17], object.realMessage);
  writer.writeDateTime(offsets[18], object.receiveAt);
  writer.writeObject<MsgReply>(
    offsets[19],
    allOffsets,
    MsgReplySchema.serialize,
    object.reply,
  );
  writer.writeInt(offsets[20], object.requestConfrim?.index);
  writer.writeLong(offsets[21], object.roomId);
  writer.writeInt(offsets[22], object.sent.index);
  writer.writeBool(offsets[23], object.stringify);
  writer.writeString(offsets[24], object.subEvent);
  writer.writeString(offsets[25], object.to);
}

Message _messageDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Message(
    content: reader.readString(offsets[2]),
    createdAt: reader.readDateTime(offsets[3]),
    encryptType:
        _MessageencryptTypeValueEnumMap[reader.readIntOrNull(offsets[4])] ??
            MessageEncryptType.signal,
    eventIds: reader.readStringList(offsets[5]) ?? [],
    from: reader.readString(offsets[6]),
    idPubkey: reader.readString(offsets[8]),
    identityId: reader.readLong(offsets[9]),
    isMeSend: reader.readBoolOrNull(offsets[10]) ?? false,
    isSystem: reader.readBoolOrNull(offsets[12]) ?? false,
    msgKeyHash: reader.readStringOrNull(offsets[14]),
    msgid: reader.readString(offsets[15]),
    rawEvents: reader.readStringList(offsets[16]) ?? [],
    realMessage: reader.readStringOrNull(offsets[17]),
    reply: reader.readObjectOrNull<MsgReply>(
      offsets[19],
      MsgReplySchema.deserialize,
      allOffsets,
    ),
    roomId: reader.readLong(offsets[21]),
    sent: _MessagesentValueEnumMap[reader.readIntOrNull(offsets[22])] ??
        SendStatusType.sending,
    to: reader.readString(offsets[25]),
  );
  object.cashuInfo = reader.readObjectOrNull<CashuInfoModel>(
    offsets[0],
    CashuInfoModelSchema.deserialize,
    allOffsets,
  );
  object.confirmResult = reader.readStringOrNull(offsets[1]);
  object.id = id;
  object.isRead = reader.readBool(offsets[11]);
  object.mediaType =
      _MessagemediaTypeValueEnumMap[reader.readIntOrNull(offsets[13])] ??
          MessageMediaType.text;
  object.receiveAt = reader.readDateTimeOrNull(offsets[18]);
  object.requestConfrim =
      _MessagerequestConfrimValueEnumMap[reader.readIntOrNull(offsets[20])];
  object.subEvent = reader.readStringOrNull(offsets[24]);
  return object;
}

P _messageDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readObjectOrNull<CashuInfoModel>(
        offset,
        CashuInfoModelSchema.deserialize,
        allOffsets,
      )) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (_MessageencryptTypeValueEnumMap[reader.readIntOrNull(offset)] ??
          MessageEncryptType.signal) as P;
    case 5:
      return (reader.readStringList(offset) ?? []) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readLong(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readLong(offset)) as P;
    case 10:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    case 11:
      return (reader.readBool(offset)) as P;
    case 12:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    case 13:
      return (_MessagemediaTypeValueEnumMap[reader.readIntOrNull(offset)] ??
          MessageMediaType.text) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readString(offset)) as P;
    case 16:
      return (reader.readStringList(offset) ?? []) as P;
    case 17:
      return (reader.readStringOrNull(offset)) as P;
    case 18:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 19:
      return (reader.readObjectOrNull<MsgReply>(
        offset,
        MsgReplySchema.deserialize,
        allOffsets,
      )) as P;
    case 20:
      return (_MessagerequestConfrimValueEnumMap[reader.readIntOrNull(offset)])
          as P;
    case 21:
      return (reader.readLong(offset)) as P;
    case 22:
      return (_MessagesentValueEnumMap[reader.readIntOrNull(offset)] ??
          SendStatusType.sending) as P;
    case 23:
      return (reader.readBoolOrNull(offset)) as P;
    case 24:
      return (reader.readStringOrNull(offset)) as P;
    case 25:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _MessageencryptTypeEnumValueMap = {
  'signal': 0,
  'nip4WrapSignal': 1,
  'nip4': 2,
  'nip4WrapNip4': 3,
  'nip17': 4,
};
const _MessageencryptTypeValueEnumMap = {
  0: MessageEncryptType.signal,
  1: MessageEncryptType.nip4WrapSignal,
  2: MessageEncryptType.nip4,
  3: MessageEncryptType.nip4WrapNip4,
  4: MessageEncryptType.nip17,
};
const _MessagemediaTypeEnumValueMap = {
  'text': 0,
  'cashuA': 1,
  'image': 2,
  'video': 3,
  'contact': 4,
  'pdf': 5,
  'setPostOffice': 6,
  'groupInvite': 7,
  'file': 8,
  'groupInviteConfirm': 9,
  'botText': 10,
  'botPricePerMessageRequest': 11,
  'botSelectionRequest': 12,
  'botOneTimePaymentRequest': 13,
};
const _MessagemediaTypeValueEnumMap = {
  0: MessageMediaType.text,
  1: MessageMediaType.cashuA,
  2: MessageMediaType.image,
  3: MessageMediaType.video,
  4: MessageMediaType.contact,
  5: MessageMediaType.pdf,
  6: MessageMediaType.setPostOffice,
  7: MessageMediaType.groupInvite,
  8: MessageMediaType.file,
  9: MessageMediaType.groupInviteConfirm,
  10: MessageMediaType.botText,
  11: MessageMediaType.botPricePerMessageRequest,
  12: MessageMediaType.botSelectionRequest,
  13: MessageMediaType.botOneTimePaymentRequest,
};
const _MessagerequestConfrimEnumValueMap = {
  'none': 0,
  'request': 1,
  'approved': 2,
  'rejected': 3,
  'expired': 4,
};
const _MessagerequestConfrimValueEnumMap = {
  0: RequestConfrimEnum.none,
  1: RequestConfrimEnum.request,
  2: RequestConfrimEnum.approved,
  3: RequestConfrimEnum.rejected,
  4: RequestConfrimEnum.expired,
};
const _MessagesentEnumValueMap = {
  'sending': 0,
  'success': 1,
  'partialSuccess': 2,
  'failed': 3,
};
const _MessagesentValueEnumMap = {
  0: SendStatusType.sending,
  1: SendStatusType.success,
  2: SendStatusType.partialSuccess,
  3: SendStatusType.failed,
};

Id _messageGetId(Message object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _messageGetLinks(Message object) {
  return [];
}

void _messageAttach(IsarCollection<dynamic> col, Id id, Message object) {
  object.id = id;
}

extension MessageByIndex on IsarCollection<Message> {
  Future<Message?> getByMsgidIdentityId(String msgid, int identityId) {
    return getByIndex(r'msgid_identityId', [msgid, identityId]);
  }

  Message? getByMsgidIdentityIdSync(String msgid, int identityId) {
    return getByIndexSync(r'msgid_identityId', [msgid, identityId]);
  }

  Future<bool> deleteByMsgidIdentityId(String msgid, int identityId) {
    return deleteByIndex(r'msgid_identityId', [msgid, identityId]);
  }

  bool deleteByMsgidIdentityIdSync(String msgid, int identityId) {
    return deleteByIndexSync(r'msgid_identityId', [msgid, identityId]);
  }

  Future<List<Message?>> getAllByMsgidIdentityId(
      List<String> msgidValues, List<int> identityIdValues) {
    final len = msgidValues.length;
    assert(identityIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([msgidValues[i], identityIdValues[i]]);
    }

    return getAllByIndex(r'msgid_identityId', values);
  }

  List<Message?> getAllByMsgidIdentityIdSync(
      List<String> msgidValues, List<int> identityIdValues) {
    final len = msgidValues.length;
    assert(identityIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([msgidValues[i], identityIdValues[i]]);
    }

    return getAllByIndexSync(r'msgid_identityId', values);
  }

  Future<int> deleteAllByMsgidIdentityId(
      List<String> msgidValues, List<int> identityIdValues) {
    final len = msgidValues.length;
    assert(identityIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([msgidValues[i], identityIdValues[i]]);
    }

    return deleteAllByIndex(r'msgid_identityId', values);
  }

  int deleteAllByMsgidIdentityIdSync(
      List<String> msgidValues, List<int> identityIdValues) {
    final len = msgidValues.length;
    assert(identityIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([msgidValues[i], identityIdValues[i]]);
    }

    return deleteAllByIndexSync(r'msgid_identityId', values);
  }

  Future<Id> putByMsgidIdentityId(Message object) {
    return putByIndex(r'msgid_identityId', object);
  }

  Id putByMsgidIdentityIdSync(Message object, {bool saveLinks = true}) {
    return putByIndexSync(r'msgid_identityId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByMsgidIdentityId(List<Message> objects) {
    return putAllByIndex(r'msgid_identityId', objects);
  }

  List<Id> putAllByMsgidIdentityIdSync(List<Message> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'msgid_identityId', objects,
        saveLinks: saveLinks);
  }
}

extension MessageQueryWhereSort on QueryBuilder<Message, Message, QWhere> {
  QueryBuilder<Message, Message, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension MessageQueryWhere on QueryBuilder<Message, Message, QWhereClause> {
  QueryBuilder<Message, Message, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<Message, Message, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Message, Message, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Message, Message, QAfterWhereClause> idBetween(
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

  QueryBuilder<Message, Message, QAfterWhereClause> msgidEqualToAnyIdentityId(
      String msgid) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'msgid_identityId',
        value: [msgid],
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterWhereClause>
      msgidNotEqualToAnyIdentityId(String msgid) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'msgid_identityId',
              lower: [],
              upper: [msgid],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'msgid_identityId',
              lower: [msgid],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'msgid_identityId',
              lower: [msgid],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'msgid_identityId',
              lower: [],
              upper: [msgid],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<Message, Message, QAfterWhereClause> msgidIdentityIdEqualTo(
      String msgid, int identityId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'msgid_identityId',
        value: [msgid, identityId],
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterWhereClause>
      msgidEqualToIdentityIdNotEqualTo(String msgid, int identityId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'msgid_identityId',
              lower: [msgid],
              upper: [msgid, identityId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'msgid_identityId',
              lower: [msgid, identityId],
              includeLower: false,
              upper: [msgid],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'msgid_identityId',
              lower: [msgid, identityId],
              includeLower: false,
              upper: [msgid],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'msgid_identityId',
              lower: [msgid],
              upper: [msgid, identityId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<Message, Message, QAfterWhereClause>
      msgidEqualToIdentityIdGreaterThan(
    String msgid,
    int identityId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'msgid_identityId',
        lower: [msgid, identityId],
        includeLower: include,
        upper: [msgid],
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterWhereClause>
      msgidEqualToIdentityIdLessThan(
    String msgid,
    int identityId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'msgid_identityId',
        lower: [msgid],
        upper: [msgid, identityId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterWhereClause>
      msgidEqualToIdentityIdBetween(
    String msgid,
    int lowerIdentityId,
    int upperIdentityId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'msgid_identityId',
        lower: [msgid, lowerIdentityId],
        includeLower: includeLower,
        upper: [msgid, upperIdentityId],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension MessageQueryFilter
    on QueryBuilder<Message, Message, QFilterCondition> {
  QueryBuilder<Message, Message, QAfterFilterCondition> cashuInfoIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'cashuInfo',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> cashuInfoIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'cashuInfo',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> confirmResultIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'confirmResult',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition>
      confirmResultIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'confirmResult',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> confirmResultEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'confirmResult',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition>
      confirmResultGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'confirmResult',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> confirmResultLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'confirmResult',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> confirmResultBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'confirmResult',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> confirmResultStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'confirmResult',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> confirmResultEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'confirmResult',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> confirmResultContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'confirmResult',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> confirmResultMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'confirmResult',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> confirmResultIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'confirmResult',
        value: '',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition>
      confirmResultIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'confirmResult',
        value: '',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> contentEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'content',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> contentGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'content',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> contentLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'content',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> contentBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'content',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> contentStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'content',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> contentEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'content',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> contentContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'content',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> contentMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'content',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> contentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'content',
        value: '',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> contentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'content',
        value: '',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> createdAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> createdAtGreaterThan(
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

  QueryBuilder<Message, Message, QAfterFilterCondition> createdAtLessThan(
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

  QueryBuilder<Message, Message, QAfterFilterCondition> createdAtBetween(
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

  QueryBuilder<Message, Message, QAfterFilterCondition> encryptTypeEqualTo(
      MessageEncryptType value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'encryptType',
        value: value,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> encryptTypeGreaterThan(
    MessageEncryptType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'encryptType',
        value: value,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> encryptTypeLessThan(
    MessageEncryptType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'encryptType',
        value: value,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> encryptTypeBetween(
    MessageEncryptType lower,
    MessageEncryptType upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'encryptType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> eventIdsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'eventIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition>
      eventIdsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'eventIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> eventIdsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'eventIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> eventIdsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'eventIds',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition>
      eventIdsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'eventIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> eventIdsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'eventIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> eventIdsElementContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'eventIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> eventIdsElementMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'eventIds',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition>
      eventIdsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'eventIds',
        value: '',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition>
      eventIdsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'eventIds',
        value: '',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> eventIdsLengthEqualTo(
      int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'eventIds',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> eventIdsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'eventIds',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> eventIdsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'eventIds',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> eventIdsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'eventIds',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition>
      eventIdsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'eventIds',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> eventIdsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'eventIds',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> fromEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'from',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> fromGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'from',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> fromLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'from',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> fromBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'from',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> fromStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'from',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> fromEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'from',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> fromContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'from',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> fromMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'from',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> fromIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'from',
        value: '',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> fromIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'from',
        value: '',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> hashCodeEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hashCode',
        value: value,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> hashCodeGreaterThan(
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

  QueryBuilder<Message, Message, QAfterFilterCondition> hashCodeLessThan(
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

  QueryBuilder<Message, Message, QAfterFilterCondition> hashCodeBetween(
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

  QueryBuilder<Message, Message, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<Message, Message, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<Message, Message, QAfterFilterCondition> idBetween(
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

  QueryBuilder<Message, Message, QAfterFilterCondition> idPubkeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'idPubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> idPubkeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'idPubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> idPubkeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'idPubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> idPubkeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'idPubkey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> idPubkeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'idPubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> idPubkeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'idPubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> idPubkeyContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'idPubkey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> idPubkeyMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'idPubkey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> idPubkeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'idPubkey',
        value: '',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> idPubkeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'idPubkey',
        value: '',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> identityIdEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'identityId',
        value: value,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> identityIdGreaterThan(
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

  QueryBuilder<Message, Message, QAfterFilterCondition> identityIdLessThan(
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

  QueryBuilder<Message, Message, QAfterFilterCondition> identityIdBetween(
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

  QueryBuilder<Message, Message, QAfterFilterCondition> isMeSendEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isMeSend',
        value: value,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> isReadEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isRead',
        value: value,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> isSystemEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSystem',
        value: value,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> mediaTypeEqualTo(
      MessageMediaType value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mediaType',
        value: value,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> mediaTypeGreaterThan(
    MessageMediaType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'mediaType',
        value: value,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> mediaTypeLessThan(
    MessageMediaType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'mediaType',
        value: value,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> mediaTypeBetween(
    MessageMediaType lower,
    MessageMediaType upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'mediaType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> msgKeyHashIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'msgKeyHash',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> msgKeyHashIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'msgKeyHash',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> msgKeyHashEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'msgKeyHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> msgKeyHashGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'msgKeyHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> msgKeyHashLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'msgKeyHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> msgKeyHashBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'msgKeyHash',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> msgKeyHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'msgKeyHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> msgKeyHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'msgKeyHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> msgKeyHashContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'msgKeyHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> msgKeyHashMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'msgKeyHash',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> msgKeyHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'msgKeyHash',
        value: '',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> msgKeyHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'msgKeyHash',
        value: '',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> msgidEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'msgid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> msgidGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'msgid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> msgidLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'msgid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> msgidBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'msgid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> msgidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'msgid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> msgidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'msgid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> msgidContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'msgid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> msgidMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'msgid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> msgidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'msgid',
        value: '',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> msgidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'msgid',
        value: '',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> rawEventsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rawEvents',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition>
      rawEventsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'rawEvents',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition>
      rawEventsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'rawEvents',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> rawEventsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'rawEvents',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition>
      rawEventsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'rawEvents',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition>
      rawEventsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'rawEvents',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition>
      rawEventsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'rawEvents',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> rawEventsElementMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'rawEvents',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition>
      rawEventsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rawEvents',
        value: '',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition>
      rawEventsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'rawEvents',
        value: '',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> rawEventsLengthEqualTo(
      int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'rawEvents',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> rawEventsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'rawEvents',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> rawEventsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'rawEvents',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> rawEventsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'rawEvents',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition>
      rawEventsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'rawEvents',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> rawEventsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'rawEvents',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> realMessageIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'realMessage',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> realMessageIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'realMessage',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> realMessageEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'realMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> realMessageGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'realMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> realMessageLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'realMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> realMessageBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'realMessage',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> realMessageStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'realMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> realMessageEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'realMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> realMessageContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'realMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> realMessageMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'realMessage',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> realMessageIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'realMessage',
        value: '',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition>
      realMessageIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'realMessage',
        value: '',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> receiveAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'receiveAt',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> receiveAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'receiveAt',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> receiveAtEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'receiveAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> receiveAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'receiveAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> receiveAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'receiveAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> receiveAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'receiveAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> replyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'reply',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> replyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'reply',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> requestConfrimIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'requestConfrim',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition>
      requestConfrimIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'requestConfrim',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> requestConfrimEqualTo(
      RequestConfrimEnum? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'requestConfrim',
        value: value,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition>
      requestConfrimGreaterThan(
    RequestConfrimEnum? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'requestConfrim',
        value: value,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> requestConfrimLessThan(
    RequestConfrimEnum? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'requestConfrim',
        value: value,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> requestConfrimBetween(
    RequestConfrimEnum? lower,
    RequestConfrimEnum? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'requestConfrim',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> roomIdEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'roomId',
        value: value,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> roomIdGreaterThan(
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

  QueryBuilder<Message, Message, QAfterFilterCondition> roomIdLessThan(
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

  QueryBuilder<Message, Message, QAfterFilterCondition> roomIdBetween(
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

  QueryBuilder<Message, Message, QAfterFilterCondition> sentEqualTo(
      SendStatusType value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sent',
        value: value,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> sentGreaterThan(
    SendStatusType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sent',
        value: value,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> sentLessThan(
    SendStatusType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sent',
        value: value,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> sentBetween(
    SendStatusType lower,
    SendStatusType upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sent',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> stringifyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'stringify',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> stringifyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'stringify',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> stringifyEqualTo(
      bool? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'stringify',
        value: value,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> subEventIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'subEvent',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> subEventIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'subEvent',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> subEventEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'subEvent',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> subEventGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'subEvent',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> subEventLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'subEvent',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> subEventBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'subEvent',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> subEventStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'subEvent',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> subEventEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'subEvent',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> subEventContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'subEvent',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> subEventMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'subEvent',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> subEventIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'subEvent',
        value: '',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> subEventIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'subEvent',
        value: '',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> toEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'to',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> toGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'to',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> toLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'to',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> toBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'to',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> toStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'to',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> toEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'to',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> toContains(String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'to',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> toMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'to',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> toIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'to',
        value: '',
      ));
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> toIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'to',
        value: '',
      ));
    });
  }
}

extension MessageQueryObject
    on QueryBuilder<Message, Message, QFilterCondition> {
  QueryBuilder<Message, Message, QAfterFilterCondition> cashuInfo(
      FilterQuery<CashuInfoModel> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'cashuInfo');
    });
  }

  QueryBuilder<Message, Message, QAfterFilterCondition> reply(
      FilterQuery<MsgReply> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'reply');
    });
  }
}

extension MessageQueryLinks
    on QueryBuilder<Message, Message, QFilterCondition> {}

extension MessageQuerySortBy on QueryBuilder<Message, Message, QSortBy> {
  QueryBuilder<Message, Message, QAfterSortBy> sortByConfirmResult() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmResult', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByConfirmResultDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmResult', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByContent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByContentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByEncryptType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'encryptType', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByEncryptTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'encryptType', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByFrom() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'from', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByFromDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'from', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByIdPubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'idPubkey', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByIdPubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'idPubkey', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByIdentityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identityId', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByIdentityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identityId', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByIsMeSend() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isMeSend', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByIsMeSendDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isMeSend', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByIsRead() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRead', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByIsReadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRead', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByIsSystem() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSystem', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByIsSystemDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSystem', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByMediaType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaType', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByMediaTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaType', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByMsgKeyHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'msgKeyHash', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByMsgKeyHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'msgKeyHash', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByMsgid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'msgid', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByMsgidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'msgid', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByRealMessage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'realMessage', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByRealMessageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'realMessage', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByReceiveAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiveAt', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByReceiveAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiveAt', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByRequestConfrim() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requestConfrim', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByRequestConfrimDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requestConfrim', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByRoomId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roomId', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByRoomIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roomId', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortBySent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sent', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortBySentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sent', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByStringifyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortBySubEvent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subEvent', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortBySubEventDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subEvent', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByTo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'to', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> sortByToDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'to', Sort.desc);
    });
  }
}

extension MessageQuerySortThenBy
    on QueryBuilder<Message, Message, QSortThenBy> {
  QueryBuilder<Message, Message, QAfterSortBy> thenByConfirmResult() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmResult', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByConfirmResultDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmResult', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByContent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByContentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByEncryptType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'encryptType', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByEncryptTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'encryptType', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByFrom() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'from', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByFromDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'from', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByIdPubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'idPubkey', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByIdPubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'idPubkey', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByIdentityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identityId', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByIdentityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identityId', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByIsMeSend() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isMeSend', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByIsMeSendDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isMeSend', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByIsRead() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRead', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByIsReadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRead', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByIsSystem() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSystem', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByIsSystemDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSystem', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByMediaType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaType', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByMediaTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaType', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByMsgKeyHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'msgKeyHash', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByMsgKeyHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'msgKeyHash', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByMsgid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'msgid', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByMsgidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'msgid', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByRealMessage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'realMessage', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByRealMessageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'realMessage', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByReceiveAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiveAt', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByReceiveAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiveAt', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByRequestConfrim() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requestConfrim', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByRequestConfrimDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requestConfrim', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByRoomId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roomId', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByRoomIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roomId', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenBySent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sent', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenBySentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sent', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByStringifyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stringify', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenBySubEvent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subEvent', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenBySubEventDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subEvent', Sort.desc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByTo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'to', Sort.asc);
    });
  }

  QueryBuilder<Message, Message, QAfterSortBy> thenByToDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'to', Sort.desc);
    });
  }
}

extension MessageQueryWhereDistinct
    on QueryBuilder<Message, Message, QDistinct> {
  QueryBuilder<Message, Message, QDistinct> distinctByConfirmResult(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'confirmResult',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Message, Message, QDistinct> distinctByContent(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'content', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Message, Message, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<Message, Message, QDistinct> distinctByEncryptType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'encryptType');
    });
  }

  QueryBuilder<Message, Message, QDistinct> distinctByEventIds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'eventIds');
    });
  }

  QueryBuilder<Message, Message, QDistinct> distinctByFrom(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'from', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Message, Message, QDistinct> distinctByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hashCode');
    });
  }

  QueryBuilder<Message, Message, QDistinct> distinctByIdPubkey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'idPubkey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Message, Message, QDistinct> distinctByIdentityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'identityId');
    });
  }

  QueryBuilder<Message, Message, QDistinct> distinctByIsMeSend() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isMeSend');
    });
  }

  QueryBuilder<Message, Message, QDistinct> distinctByIsRead() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isRead');
    });
  }

  QueryBuilder<Message, Message, QDistinct> distinctByIsSystem() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSystem');
    });
  }

  QueryBuilder<Message, Message, QDistinct> distinctByMediaType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mediaType');
    });
  }

  QueryBuilder<Message, Message, QDistinct> distinctByMsgKeyHash(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'msgKeyHash', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Message, Message, QDistinct> distinctByMsgid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'msgid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Message, Message, QDistinct> distinctByRawEvents() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rawEvents');
    });
  }

  QueryBuilder<Message, Message, QDistinct> distinctByRealMessage(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'realMessage', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Message, Message, QDistinct> distinctByReceiveAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'receiveAt');
    });
  }

  QueryBuilder<Message, Message, QDistinct> distinctByRequestConfrim() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'requestConfrim');
    });
  }

  QueryBuilder<Message, Message, QDistinct> distinctByRoomId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'roomId');
    });
  }

  QueryBuilder<Message, Message, QDistinct> distinctBySent() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sent');
    });
  }

  QueryBuilder<Message, Message, QDistinct> distinctByStringify() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'stringify');
    });
  }

  QueryBuilder<Message, Message, QDistinct> distinctBySubEvent(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'subEvent', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Message, Message, QDistinct> distinctByTo(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'to', caseSensitive: caseSensitive);
    });
  }
}

extension MessageQueryProperty
    on QueryBuilder<Message, Message, QQueryProperty> {
  QueryBuilder<Message, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Message, CashuInfoModel?, QQueryOperations> cashuInfoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cashuInfo');
    });
  }

  QueryBuilder<Message, String?, QQueryOperations> confirmResultProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'confirmResult');
    });
  }

  QueryBuilder<Message, String, QQueryOperations> contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'content');
    });
  }

  QueryBuilder<Message, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<Message, MessageEncryptType, QQueryOperations>
      encryptTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'encryptType');
    });
  }

  QueryBuilder<Message, List<String>, QQueryOperations> eventIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'eventIds');
    });
  }

  QueryBuilder<Message, String, QQueryOperations> fromProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'from');
    });
  }

  QueryBuilder<Message, int, QQueryOperations> hashCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hashCode');
    });
  }

  QueryBuilder<Message, String, QQueryOperations> idPubkeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'idPubkey');
    });
  }

  QueryBuilder<Message, int, QQueryOperations> identityIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'identityId');
    });
  }

  QueryBuilder<Message, bool, QQueryOperations> isMeSendProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isMeSend');
    });
  }

  QueryBuilder<Message, bool, QQueryOperations> isReadProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isRead');
    });
  }

  QueryBuilder<Message, bool, QQueryOperations> isSystemProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSystem');
    });
  }

  QueryBuilder<Message, MessageMediaType, QQueryOperations>
      mediaTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mediaType');
    });
  }

  QueryBuilder<Message, String?, QQueryOperations> msgKeyHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'msgKeyHash');
    });
  }

  QueryBuilder<Message, String, QQueryOperations> msgidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'msgid');
    });
  }

  QueryBuilder<Message, List<String>, QQueryOperations> rawEventsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rawEvents');
    });
  }

  QueryBuilder<Message, String?, QQueryOperations> realMessageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'realMessage');
    });
  }

  QueryBuilder<Message, DateTime?, QQueryOperations> receiveAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'receiveAt');
    });
  }

  QueryBuilder<Message, MsgReply?, QQueryOperations> replyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reply');
    });
  }

  QueryBuilder<Message, RequestConfrimEnum?, QQueryOperations>
      requestConfrimProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'requestConfrim');
    });
  }

  QueryBuilder<Message, int, QQueryOperations> roomIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'roomId');
    });
  }

  QueryBuilder<Message, SendStatusType, QQueryOperations> sentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sent');
    });
  }

  QueryBuilder<Message, bool?, QQueryOperations> stringifyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stringify');
    });
  }

  QueryBuilder<Message, String?, QQueryOperations> subEventProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'subEvent');
    });
  }

  QueryBuilder<Message, String, QQueryOperations> toProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'to');
    });
  }
}

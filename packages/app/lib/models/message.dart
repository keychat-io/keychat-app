import 'package:app/models/embedded/cashu_info.dart';
import 'package:app/models/embedded/msg_file_info.dart';
import 'package:app/models/embedded/msg_reply.dart';

import 'package:equatable/equatable.dart';
import 'package:isar/isar.dart';

part 'message.g.dart';

enum SendStatusType { sending, success, partialSuccess, failed }

enum MessageEncryptType { signal, nip4WrapSignal, nip4, nip4WrapNip4, nip17 }

enum MessageMediaType {
  text,
  cashuA,
  image,
  video,
  contact,
  pdf,
  setPostOffice,
  groupInvite,
  file,
  groupInviteConfirm, // For administrators to use to accept or deny new users from joining the group
  // bot message from the bot service
  botText,
  botPricePerMessageRequest,
  botSelectionRequest,
  botOneTimePaymentRequest
}

enum RequestConfrimEnum { none, request, approved, rejected, expired }

@Collection(ignore: {'props', 'relayStatusMap', 'fromContact'})
// ignore: must_be_immutable
class Message extends Equatable {
  Id id = Isar.autoIncrement;

  @Index(unique: true, composite: [CompositeIndex('identityId')])
  late String msgid; // event.id
  late String from; // event' from address
  late String to; // event's to address
  late String content; // event's content
  String? realMessage; // show in room page
  late DateTime createdAt; // event's createdAt

  late int identityId;
  late String idPubkey; // the sender id pubkey
  List<String> eventIds = []; // for pairwise group
  late int roomId;

  MsgReply? reply;
  CashuInfoModel? cashuInfo; // cashu
  String? msgKeyHash;

  @Enumerated(EnumType.ordinal32)
  SendStatusType sent = SendStatusType.success; // status

  @Enumerated(EnumType.ordinal32)
  MessageMediaType mediaType = MessageMediaType.text;

  @Enumerated(EnumType.ordinal32)
  MessageEncryptType encryptType = MessageEncryptType.signal;

  bool isRead = false;
  bool isSystem = false;
  bool isMeSend = false;

  @Enumerated(EnumType.ordinal32)
  RequestConfrimEnum? requestConfrim;

  // which option is selected
  String? confirmResult;

  String? subEvent;
  DateTime? receiveAt;
  List<String> rawEvents = [];
  FromContact? fromContact; // show for message

  Message(
      {required this.msgid,
      required this.idPubkey,
      required this.identityId,
      required this.roomId,
      required this.from,
      required this.to,
      required this.content,
      required this.createdAt,
      required this.sent,
      required this.eventIds,
      required this.encryptType,
      required this.rawEvents,
      this.realMessage,
      this.reply,
      this.isSystem = false,
      this.isMeSend = false,
      this.msgKeyHash});

  @override
  List<Object?> get props => [
        id,
        content,
        realMessage,
        msgid,
        roomId,
        from,
        to,
        isSystem,
        isMeSend,
        isRead,
        mediaType,
        createdAt,
      ];

  MsgFileInfo? convertToMsgFileInfo() {
    if (content.startsWith('https://') || content.startsWith('http://')) {
      Uri uri = Uri.parse(content);
      if (!uri.hasQuery) return null;
      Map query = uri.queryParameters;
      if (query['kctype'] == null) return null;

      return MsgFileInfo()
        ..type = query['kctype']
        ..url = uri.origin + uri.path
        ..iv = query['iv']
        ..suffix = query['suffix']
        ..key = query['key']
        ..size = int.parse(query['size'] ?? 0)
        ..status = FileStatus.init;
    }
    return null;
  }
}

class FromContact {
  late String pubkey;
  late String name;
  FromContact(this.pubkey, this.name);
}

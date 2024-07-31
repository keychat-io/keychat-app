import 'dart:convert' show jsonEncode;

import 'package:app/constants.dart';

import 'package:app/models/models.dart';
import 'package:app/models/signal_id.dart';
import 'package:app/service/chatx.service.dart';
import 'package:app/service/group.service.dart';
import 'package:app/service/room.service.dart';
import 'package:get/get.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../service/chat.service.dart';
import '../../service/nip4Chat.service.dart';
import '../../service/signalChat.service.dart';

part 'keychat_message.g.dart';

@JsonSerializable(includeIfNull: false)
class KeychatMessage {
  MessageType c;
  late int type; // = KeyChatEventKinds.start;
  String? msg;
  String? name;

  KeychatMessage({
    required this.type,
    required this.c, // category
    this.msg,
    this.name,
  });
  BaseChatService get service {
    // common proccess
    if (type > 2000) {
      return RoomService();
    }

    switch (c) {
      case MessageType.nip04:
        return Nip4ChatService();
      case MessageType.signal:
        return SignalChatService();
      case MessageType.group:
        return GroupService();
    }
  }

  factory KeychatMessage.fromJson(Map<String, dynamic> json) =>
      _$KeychatMessageFromJson(json);

  Map<String, dynamic> toJson() => _$KeychatMessageToJson(this);

  @override
  String toString() => jsonEncode(toJson());

  Future<KeychatMessage> setHelloMessagge(Identity identity,
      {String? greeting, String? relay}) async {
    List<SignalId> signalIds = await ChatxService().getSignalIds(identity.id);
    if (signalIds.isEmpty) throw Exception('No signalId found');
    SignalId signalId = signalIds.first;

    List<Mykey> oneTimeKeys =
        await ChatxService().getOneTimePubkey(identity.id);
    String onetimekey = '';
    if (oneTimeKeys.isNotEmpty) {
      onetimekey = oneTimeKeys.first.pubkey;
    }

    Map userInfo = await Get.find<ChatxService>().getQRCodeData(signalId);

    Map<String, dynamic> data = {
      'name': identity.displayName,
      'pubkey': identity.secp256k1PKHex,
      'curve25519PkHex': signalId.pubkey,
      'onetimekey': onetimekey,
      'time': -1,
      'relay': "",
      "globalSign": "",
      ...userInfo
    };
    name = QRUserModel.fromJson(data).toString();
    msg = '''
😄Hi, I'm ${identity.displayName}.
Let's start an encrypted chat.''';
    if (greeting != null && greeting.isNotEmpty) {
      msg = '''
$msg

Greeting:
$greeting''';
    }
    return this;
  }

  /// if no relay, return content. if has replay , return KeychatMessage Object;
  static String getTextMessage(
      MessageType messageType, String content, MsgReply? reply) {
    if (reply == null) return content;
    return KeychatMessage(
            type: KeyChatEventKinds.dm,
            c: messageType,
            msg: content,
            name: reply.toString())
        .toString();
  }
}

enum MessageType { nip04, signal, group }

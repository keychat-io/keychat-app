import 'dart:convert' show jsonEncode;

import 'package:app/constants.dart';

import 'package:app/models/models.dart';
import 'package:app/models/signal_id.dart';
import 'package:app/service/chatx.service.dart';
import 'package:app/service/group.service.dart';
import 'package:app/service/kdf_group.service.dart';
import 'package:app/service/signalId.service.dart';
import 'package:get/get.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../service/chat.service.dart';
import '../../service/nip4_chat.service.dart';
import '../../service/signal_chat.service.dart';

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
    switch (c) {
      case MessageType.nip04:
        return Nip4ChatService();
      case MessageType.signal:
        return SignalChatService();
      case MessageType.group:
        return GroupService();
      case MessageType.kdfGroup:
        return KdfGroupService.instance;
    }
  }

  factory KeychatMessage.fromJson(Map<String, dynamic> json) =>
      _$KeychatMessageFromJson(json);

  Map<String, dynamic> toJson() => _$KeychatMessageToJson(this);

  @override
  String toString() => jsonEncode(toJson());

  Future<KeychatMessage> setHelloMessagge(Identity identity,
      {SignalId? signalId, String? greeting}) async {
    List<Mykey> oneTimeKeys =
        await Get.find<ChatxService>().getOneTimePubkey(identity.id);
    String onetimekey = '';
    if (oneTimeKeys.isNotEmpty) {
      onetimekey = oneTimeKeys.first.pubkey;
    }

    signalId ??= await SignalIdService.instance.createSignalId(identity.id);
    if (signalId == null) throw Exception('signalId is null');

    Map userInfo = await SignalIdService.instance.getQRCodeData(signalId);

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

enum MessageType { nip04, signal, group, kdfGroup }

import 'dart:convert' show jsonEncode;

import 'package:app/constants.dart';
import 'package:app/global.dart';

import 'package:app/models/models.dart';
import 'package:app/models/signal_id.dart';
import 'package:app/service/chatx.service.dart';
import 'package:app/service/group.service.dart';
import 'package:app/service/mls_group.service.dart';
import 'package:app/service/signalId.service.dart';
import 'package:app/service/signal_chat_util.dart';
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
  String? data;

  KeychatMessage(
      {required this.type,
      required this.c, // category
      this.msg,
      this.name,
      this.data});
  BaseChatService get service {
    switch (c) {
      case MessageType.nip04:
        return Nip4ChatService.instance;
      case MessageType.signal:
        return SignalChatService.instance;
      case MessageType.group:
        return GroupService.instance;
      case MessageType.mls:
        return MlsGroupService.instance;
      case MessageType.kdfGroup:
        throw Exception('kdfGroup not support');
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
    int expiredTime = DateTime.now().millisecondsSinceEpoch +
        KeychatGlobal.oneTimePubkeysLifetime * 3600 * 1000;

    String content = SignalChatUtil.getToSignMessage(
      nostrId: identity.secp256k1PKHex,
      signalId: signalId.pubkey,
      time: expiredTime,
    );
    String? sig = await SignalChatUtil.signByIdentity(
        identity: identity, content: content, id: expiredTime.toString());
    if (sig == null) throw Exception('Sign failed or User denied');
    Map<String, dynamic> data = {
      'name': identity.displayName,
      'pubkey': identity.secp256k1PKHex,
      'curve25519PkHex': signalId.pubkey,
      'onetimekey': onetimekey,
      'time': expiredTime,
      'relay': "",
      "globalSign": sig,
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

  static String getFeatureMessageString(
      MessageType type, Room room, String message, int subtype,
      {String? name, String? data}) {
    KeychatMessage km = KeychatMessage(
        c: type, type: subtype, msg: message, data: data, name: name);
    return km.toString();
  }
}

enum MessageType { nip04, signal, group, kdfGroup, mls }

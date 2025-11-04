import 'dart:convert' show jsonEncode;

import 'package:keychat/constants.dart';
import 'package:keychat/models/models.dart';
import 'package:keychat/page/chat/RoomUtil.dart';
import 'package:keychat/service/chat.service.dart';
import 'package:keychat/service/chatx.service.dart';
import 'package:keychat/service/group.service.dart';
import 'package:keychat/service/mls_group.service.dart';
import 'package:keychat/service/nip4_chat.service.dart';
import 'package:keychat/service/signalId.service.dart';
import 'package:keychat/service/signal_chat.service.dart';
import 'package:keychat/service/signal_chat_util.dart';
import 'package:get/get.dart';
import 'package:json_annotation/json_annotation.dart';

part 'keychat_message.g.dart';

@JsonSerializable(includeIfNull: false)
class KeychatMessage {
  KeychatMessage({
    required this.type,
    required this.c, // category
    this.msg,
    this.name,
    this.data,
  });

  factory KeychatMessage.fromJson(Map<String, dynamic> json) =>
      _$KeychatMessageFromJson(json);
  MessageType c;
  late int type; // = KeyChatEventKinds.start;
  String? msg;
  String? name;
  String? data;
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

  Map<String, dynamic> toJson() => _$KeychatMessageToJson(this);

  @override
  String toString() => jsonEncode(toJson());

  Future<KeychatMessage> setHelloMessagge(
    Identity identity, {
    SignalId? signalId,
    String? greeting,
    bool fromNpub = false,
  }) async {
    final oneTimeKeys = await Get.find<ChatxService>().getOneTimePubkey(
      identity.id,
    );
    var onetimekey = '';
    if (oneTimeKeys.isNotEmpty) {
      onetimekey = oneTimeKeys.first.pubkey;
    }

    signalId ??= await SignalIdService.instance.createSignalId(identity.id);

    final time = RoomUtil.getValidateTime();
    final userInfo = await SignalIdService.instance.getQRCodeData(
      signalId,
      time,
    );

    final content = SignalChatUtil.getToSignMessage(
      nostrId: identity.secp256k1PKHex,
      signalId: signalId.pubkey,
      time: time,
    );
    final sig = await SignalChatUtil.signByIdentity(
      identity: identity,
      content: content,
      id: time.toString(),
    );

    if (sig == null) throw Exception('Sign failed or User denied');
    final avatarRemoteUrl = await identity.getRemoteAvatarUrl();

    final data = <String, dynamic>{
      'name': identity.displayName,
      'pubkey': identity.secp256k1PKHex,
      'curve25519PkHex': signalId.pubkey,
      'onetimekey': onetimekey,
      'time': time,
      'relay': '',
      'lightning': identity.lightning ?? '',
      'avatar': avatarRemoteUrl ?? '',
      'globalSign': sig,
      ...userInfo.cast<String, dynamic>(),
    };
    name = QRUserModel.fromJson(data).toString();
    msg = fromNpub
        ? '''
😄Hi, I'm ${identity.displayName}.
Request to start an encrypted chat.'''
        : '''
😄Hi, I'm ${identity.displayName}.
Let's start an encrypted chat.''';
    if (greeting != null && greeting.isNotEmpty) {
      msg =
          '''
$msg

Greeting:
$greeting''';
    }
    return this;
  }

  /// if no relay, return content. if has replay , return KeychatMessage Object;
  static String getTextMessage(
    MessageType messageType,
    String content,
    MsgReply? reply,
  ) {
    if (reply == null) return content;
    return KeychatMessage(
      type: KeyChatEventKinds.dm,
      c: messageType,
      msg: content,
      name: reply.toString(),
    ).toString();
  }

  static String getFeatureMessageString(
    MessageType type,
    Room room,
    String message,
    int subtype, {
    String? name,
    String? data,
  }) {
    final km = KeychatMessage(
      c: type,
      type: subtype,
      msg: message,
      data: data,
      name: name,
    );
    return km.toString();
  }
}

enum MessageType { nip04, signal, group, kdfGroup, mls }

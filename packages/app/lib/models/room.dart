import 'dart:convert';

import 'package:app/bot/bot_server_message_model.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/models/models.dart';

import 'package:app/models/signal_id.dart';
import 'package:app/service/chatx.service.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/service/signalId.service.dart';
import 'package:app/utils.dart';
import 'package:equatable/equatable.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:keychat_rust_ffi_plugin/api_signal.dart';

import 'db_provider.dart';

part 'room.g.dart';

enum RoomType { common, private, group, bot }

enum GroupType { shareKey, sendAll, kdf }

enum EncryptMode { nip04, signal }

enum RoomStatus {
  init, // create success  not show in room list
  requesting, // sender status
  approving, // receiver handle
  approvingNoResponse, // receiver handle but not response
  rejected, // receiver rejectd
  enabled,
  disabled,
  dissolved,
  removedFromGroup, // removed from group
  groupUser, // not show in room list. used by group
}

@Collection(ignore: {
  'props',
  'contact',
  'unReadCount',
  'lastMessageModel',
  'isSendAllGroup',
  'isShareKeyGroup',
  'isKDFGroup',
  'parentRoom',
  'keyPair'
})
// ignore: must_be_immutable
class Room extends Equatable {
  Id id = Isar.autoIncrement;

  @Index(unique: true, composite: [CompositeIndex('identityId')])
  late String toMainPubkey;
  late String npub;

  // their(Bob) signal id pubkey
  String? curve25519PkHex;
  // my(alice) signal id pubkey
  String? signalIdPubkey;

  String? avatar;

  late int identityId;

  @Enumerated(EnumType.ordinal32)
  late RoomType type;

  @Enumerated(EnumType.ordinal32)
  late EncryptMode encryptMode = EncryptMode.nip04;

  @Enumerated(EnumType.ordinal32)
  GroupType groupType = GroupType.shareKey;

  @Enumerated(EnumType.ordinal32)
  late RoomStatus status;

  int autoDeleteDays = 0;
  // group opration version
  int version = 0;

  final mykey = IsarLink<Mykey>();

  late DateTime createdAt;

  // pin
  bool pin = false;
  DateTime? pinAt;

  // group info
  String? name;
  String? description;
  bool isMute = false; // mute notification

  bool signalDecodeError = false; // if decode error set: true

  int unReadCount = 0;
  Message? lastMessageModel;
  Contact? contact; // room'contact info
  Room? parentRoom; // for group room

  String? onetimekey;
  String? sharedSignalID; // a shared virtual signal id for group

  // bot
  String? botInfo; // json map string, fetch from relay or hello message
  String? botLocalConfig; // json map string, user config in local
  int botInfoUpdatedAt = 0; // bot metadata update time

  // relays
  List<String> receivingRelays = [];
  List<String> sendingRelays = [];

  Room(
      {required this.toMainPubkey,
      required this.npub,
      required this.identityId,
      required this.status,
      this.type = RoomType.common}) {
    createdAt = DateTime.now();
  }

  bool get isSendAllGroup =>
      groupType == GroupType.sendAll && type == RoomType.group;
  bool get isShareKeyGroup =>
      groupType == GroupType.shareKey && type == RoomType.group;
  bool get isKDFGroup => groupType == GroupType.kdf && type == RoomType.group;

  @override
  List<Object?> get props => [
        id,
        toMainPubkey,
        mykey,
        createdAt,
        unReadCount,
        name,
        // groupChat
      ];

  String get myIdPubkey => getIdentity().secp256k1PKHex;

  // if exist signalIdPubkey return it ,else use identity's keypair
  Future<KeychatIdentityKeyPair> getKeyPair() async {
    ChatxService chatxService = Get.find<ChatxService>();
    if (signalIdPubkey == null) {
      return await chatxService.getKeyPairByIdentity(getIdentity());
    }
    var exist = chatxService.initedKeypairs[signalIdPubkey];
    if (exist != null) return exist;
    SignalId? si = getMySignalId();
    if (si != null) {
      return chatxService.setupSignalStoreBySignalId(si.pubkey, si);
    }
    return throw Exception('signalId is null');
  }

  Future<KeychatIdentityKeyPair?> getSharedKeyPair() async {
    SignalId? id;
    try {
      id = getGroupSharedSignalId();
    } catch (e) {}
    if (id == null) return null;

    return Get.find<ChatxService>().getKeyPairBySignalId(id);
  }

  Identity getIdentity() {
    return Get.find<HomeController>().identities[identityId]!;
  }

  SignalId? getMySignalId() {
    if (signalIdPubkey == null) return null;

    SignalId? res = DBProvider.database.signalIds
        .filter()
        .pubkeyEqualTo(signalIdPubkey!)
        .identityIdEqualTo(identityId)
        .findFirstSync();
    return res;
  }

  SignalId getGroupSharedSignalId() {
    if (sharedSignalID == null) throw Exception('signalId is null');

    SignalId? res = DBProvider.database.signalIds
        .filter()
        .pubkeyEqualTo(sharedSignalID!)
        .findFirstSync();
    if (res == null) throw Exception('signalId is null');
    return res;
  }

  Future<RoomMember?> getMemberByIdPubkey(String pubkey) async {
    Isar database = DBProvider.database;

    return await database.roomMembers
        .filter()
        .roomIdEqualTo(id)
        .idPubkeyEqualTo(pubkey)
        .findFirst();
  }

  Future<RoomMember?> getMember(String pubkey) async {
    Isar database = DBProvider.database;
    return await database.roomMembers
        .filter()
        .roomIdEqualTo(id)
        .idPubkeyEqualTo(pubkey)
        .findFirst();
  }

  Future<RoomMember?> getEnableMember(String pubkey) async {
    Isar database = DBProvider.database;
    return await database.roomMembers
        .filter()
        .roomIdEqualTo(id)
        .idPubkeyEqualTo(pubkey)
        .statusEqualTo(UserStatusType.invited)
        .findFirst();
  }

  Future<List<RoomMember>> getMembers() async {
    return await DBProvider.database.roomMembers
        .filter()
        .roomIdEqualTo(id)
        .findAll();
  }

  Future<List<RoomMember>> getEnableMembers() async {
    return await DBProvider.database.roomMembers
        .filter()
        .roomIdEqualTo(id)
        .statusEqualTo(UserStatusType.invited)
        .findAll();
  }

  // inviting + invited
  Future<List<RoomMember>> getActiveMembers() async {
    return await DBProvider.database.roomMembers
        .filter()
        .roomIdEqualTo(id)
        .group((q) => q
            .statusEqualTo(UserStatusType.invited)
            .or()
            .statusEqualTo(UserStatusType.inviting))
        .findAll();
  }

  Future<List<RoomMember>> getInvitingMembers() async {
    return await DBProvider.database.roomMembers
        .filter()
        .roomIdEqualTo(id)
        .statusEqualTo(UserStatusType.inviting)
        .findAll();
  }

  Future<bool> checkAdminByIdPubkey(String pubkey) async {
    int count = await DBProvider.database.roomMembers
        .filter()
        .roomIdEqualTo(id)
        .idPubkeyEqualTo(pubkey)
        .isAdminEqualTo(true)
        .count();
    return count > 0;
  }

  Future<RoomMember?> getAdmin() async {
    Isar database = DBProvider.database;

    return await database.roomMembers
        .filter()
        .roomIdEqualTo(id)
        .isAdminEqualTo(true)
        .findFirst();
  }

  // metadata
  Future<RoomMember> addMember({
    required String name,
    required String idPubkey,
    String? curve25519PkHex,
    required UserStatusType status,
    required DateTime updatedAt,
    required DateTime createdAt,
    bool isAdmin = false,
  }) async {
    Isar database = DBProvider.database;

    RoomMember? rm = await getMemberByIdPubkey(idPubkey);
    if (rm == null) {
      rm = RoomMember(idPubkey: idPubkey, name: name, roomId: id)
        ..createdAt = createdAt
        ..updatedAt = updatedAt;
      rm.isAdmin = isAdmin;
      rm.status = status;
    } else {
      if (rm.updatedAt != null) {
        if (rm.updatedAt!.isAfter(updatedAt)) {
          return rm;
        } else {
          // update
          rm.name = name;
          rm.isAdmin = isAdmin;
          rm.status = status;
          rm.updatedAt = updatedAt;
        }
      }
    }
    await database.writeTxn(() async {
      await database.roomMembers.put(rm!);
    });
    return rm;
  }

  Future updateAllMember(List<dynamic> list) async {
    Isar database = DBProvider.database;
    if (list.isEmpty) return;
    await database.writeTxn(() async {
      // await database.roomMembers.filter().roomIdEqualTo(id).deleteAll();
      for (var user in list) {
        user['roomId'] = id;
        RoomMember rm = RoomMember.fromJson(user);
        RoomMember? exist = await database.roomMembers
            .filter()
            .roomIdEqualTo(id)
            .idPubkeyEqualTo(rm.idPubkey)
            .findFirst();
        if (exist != null) {
          if (exist.updatedAt != null && rm.updatedAt != null) {
            if (exist.updatedAt!.isAfter(rm.updatedAt!)) {
              logger.d('Ingore by updatedAt: ${exist.idPubkey}');
              continue;
            }
          }
          exist.name = rm.name;
          exist.isAdmin = rm.isAdmin;
          exist.status = rm.status;
          if (rm.createdAt != null) {
            exist.createdAt = rm.createdAt;
          }
          if (rm.updatedAt != null) {
            exist.updatedAt = rm.updatedAt;
          }
          await database.roomMembers.put(exist);
        } else {
          await database.roomMembers.put(rm);
        }
      }
    });
  }

  Future updateAllMemberTx(List<dynamic> list) async {
    Isar database = DBProvider.database;
    if (list.isEmpty) return;
    for (var user in list) {
      late RoomMember rm;
      if (user is RoomMember) {
        user.roomId = id;
        rm = user;
      } else {
        user['roomId'] = id;
        rm = RoomMember.fromJson(user);
      }
      RoomMember? exist = await database.roomMembers
          .filter()
          .roomIdEqualTo(id)
          .idPubkeyEqualTo(rm.idPubkey)
          .findFirst();
      if (exist == null) {
        rm.messageCount = 0;
        await database.roomMembers.put(rm);
        continue;
      }

      exist.name = rm.name;
      exist.messageCount = 0;
      exist.isAdmin = rm.isAdmin;
      exist.status = rm.status;
      if (rm.createdAt != null) {
        exist.createdAt = rm.createdAt;
      }
      if (rm.updatedAt != null) {
        exist.updatedAt = rm.updatedAt;
      }
      await database.roomMembers.put(exist);
    }
  }

  Future<void> setMemberInvited(RoomMember rm, String? name) async {
    if (rm.status != UserStatusType.invited) {
      rm.status = UserStatusType.invited;
      if (name != null) rm.name = name;
      await updateMember(rm);
      RoomService.getController(id)?.resetMembers();
    }
  }

  Future updateMember(RoomMember rm) async {
    Isar database = DBProvider.database;
    await database.writeTxn(() async {
      await database.roomMembers.put(rm);
    });
  }

  updateMemberName(String pubkey, String name) async {
    Isar database = DBProvider.database;

    RoomMember? rm = await getMemberByIdPubkey(pubkey);
    if (rm == null) return;
    rm.name = name;
    await database.writeTxn(() async {
      await database.roomMembers.put(rm);
    });
  }

  // soft delete
  Future removeMember(String idPubkey) async {
    Isar database = DBProvider.database;
    RoomMember? rm = await getMemberByIdPubkey(idPubkey);
    if (rm == null) return;

    await database.writeTxn(() async {
      rm.status = UserStatusType.removed;
      await database.roomMembers.put(rm);
    });
  }

  Future setMemberDisable(RoomMember rm) async {
    RoomMember? model = await DBProvider.database.roomMembers
        .filter()
        .roomIdEqualTo(rm.roomId)
        .idPubkeyEqualTo(rm.idPubkey)
        .findFirst();
    if (model == null) return;
    await DBProvider.database.writeTxn(() async {
      model.status = UserStatusType.removed;
      await DBProvider.database.roomMembers.put(model);
    });
  }

  String getRoomName() {
    if (type == RoomType.group) {
      return name!;
    }

    if (contact == null) {
      return name ?? getPublicKeyDisplay(npub);
    }
    return contact!.displayName;
  }

  Future<Map<String, Room>> getEnableMemberRooms() async {
    Map<String, Room> memberRooms = {};
    List<RoomMember> rms = await getEnableMembers();
    for (RoomMember rm in rms) {
      if (rm.idPubkey == myIdPubkey) continue;

      Room idRoom = await RoomService().getOrCreateRoom(
          rm.idPubkey, myIdPubkey, RoomStatus.groupUser,
          contactName: rm.name);
      memberRooms[rm.idPubkey] = idRoom;
    }
    return memberRooms;
  }

  Future<Map<String, Room>> getActiveMemberRooms(Mykey mainMykey) async {
    Map<String, Room> memberRooms = {};
    List<RoomMember> rms = await getMembers();
    for (RoomMember rm in rms) {
      if (rm.idPubkey == mainMykey.pubkey) continue;

      Room idRoom = await RoomService()
          .getOrCreateRoom(rm.idPubkey, mainMykey.pubkey, RoomStatus.groupUser);
      memberRooms[rm.idPubkey] = idRoom;
    }
    return memberRooms;
  }

  Future<RoomMember?> getMemberByNostrPubkey(String pubkey) async {
    return await DBProvider.database.roomMembers
        .filter()
        .roomIdEqualTo(id)
        .idPubkeyEqualTo(pubkey)
        .findFirst();
  }

  int getDeviceIdForSignal() {
    return type == RoomType.common ? identityId : 10000 + id;
  }

  Future createMember(
      String pubkey, String displayName, UserStatusType status) async {
    var me = RoomMember(idPubkey: pubkey, name: displayName, roomId: id)
      ..status = status
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.roomMembers.put(me);
    });
    return getMemberByNostrPubkey(pubkey);
  }

  Future incrMessageCountForMember(RoomMember member) async {
    bool changeMember = false;
    if (member.status != UserStatusType.invited) {
      member.status = UserStatusType.invited;
      changeMember = true;
    }
    await DBProvider.database.writeTxn(() async {
      member.messageCount++;
      await DBProvider.database.roomMembers.put(member);
    });
    if (changeMember) {
      RoomService.getController(id)?.resetMembers();
    }
  }

  // clear keys. if receive all member's prekey message
  // clear keys. if reach the expired time
  Future checkAndCleanSignalKeys() async {
    if (groupType != GroupType.kdf) return;
    int count = await DBProvider.database.roomMembers
        .filter()
        .roomIdEqualTo(id)
        .messageCountLessThan(KeychatGlobal.kdfGroupPrekeyMessageCount + 1)
        .group((q) => q
            .statusEqualTo(UserStatusType.invited)
            .or()
            .statusEqualTo(UserStatusType.inviting))
        .count();
    SignalId? signalId =
        await SignalIdService.instance.getSignalIdByPubkey(sharedSignalID);
    if (signalId == null) return;
    if (count > 0) {
      DateTime expiredAt = signalId.updatedAt
          .add(Duration(days: KeychatGlobal.kdfGroupKeysExpired));
      if (expiredAt.isAfter(DateTime.now())) return; // not need to delete keys
    }
    if (signalId.keys == null || (signalId.keys?.isEmpty ?? true)) return;
    logger.i('clean signal keys: $toMainPubkey');
    signalId.keys = "";
    await SignalIdService.instance.updateSignalId(signalId);
    MessageService()
        .saveSystemMessage(this, 'Clear shared signal-id-keys successfully');
  }

  String getDebugInfo(String error) {
    return '''$error
Room: $id, ${getRoomName()} $toMainPubkey, $identityId, $groupType''';
  }

  BotMessageData? getBotMessagePriceModel() {
    if (botLocalConfig == null) return null;
    BotMessageData? bmd;
    try {
      Map config = jsonDecode(botLocalConfig!);
      bmd = BotMessageData.fromJson(
          config[MessageMediaType.botPricePerMessageRequest.name]);
    } catch (e) {
      return null;
    }
    return bmd;
  }
}

import 'dart:convert';

import 'package:app/bot/bot_server_message_model.dart';

import 'package:app/controller/home.controller.dart';
import 'package:app/models/models.dart';

import 'package:app/service/chatx.service.dart';
import 'package:app/service/mls_group.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/utils.dart';
import 'package:equatable/equatable.dart';
import 'package:get/get.dart';
import 'package:isar_community/isar.dart';
import 'package:keychat_rust_ffi_plugin/api_signal.dart';

part 'room.g.dart';

enum RoomType {
  common,
  @Deprecated('use common instead')
  private,
  group,
  bot
}

enum GroupType {
  @Deprecated('use mls instead')
  shareKey,
  sendAll,
  @Deprecated('use mls instead')
  kdf,
  mls
}

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

@Collection(
  ignore: {
    'props',
    'contact',
    'unReadCount',
    'lastMessageModel',
    'isSendAllGroup',
    'isShareKeyGroup',
    'isKDFGroup',
    'isMLSGroup',
    'parentRoom',
    'keyPair',
  },
)
// ignore: must_be_immutable
class Room extends Equatable {
  // for mls group

  Room({
    required this.toMainPubkey,
    required this.npub,
    required this.identityId,
    this.status = RoomStatus.enabled,
    this.type = RoomType.common,
  }) {
    createdAt = DateTime.now();
  }
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
  GroupType groupType = GroupType.mls;

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
  bool sentHelloToMLS = false;

  bool get isSendAllGroup =>
      groupType == GroupType.sendAll && type == RoomType.group;
  @Deprecated('shareKey Group is deprecated')
  bool get isShareKeyGroup =>
      groupType == GroupType.shareKey && type == RoomType.group;

  @Deprecated('KDF Group is deprecated')
  bool get isKDFGroup => groupType == GroupType.kdf && type == RoomType.group;
  bool get isMLSGroup => groupType == GroupType.mls && type == RoomType.group;

  @override
  List<Object?> get props => [
        id,
        toMainPubkey,
        createdAt,
        unReadCount,
        name,
        status,
        type,
      ];

  String get myIdPubkey => getIdentity().secp256k1PKHex;

  // if exist signalIdPubkey return it ,else use identity's keypair
  Future<KeychatIdentityKeyPair> getKeyPair() async {
    final chatxService = Get.find<ChatxService>();
    if (signalIdPubkey == null) {
      return chatxService.getKeyPairByIdentity(getIdentity());
    }
    final si = getMySignalId();
    if (si != null) {
      return chatxService.setupSignalStoreBySignalId(si.pubkey, si);
    }
    return throw Exception('signalId is null');
  }

  Future<KeychatIdentityKeyPair?> getSharedKeyPair() async {
    SignalId? id;
    try {
      id = getGroupSharedSignalId();
      // ignore: empty_catches
    } catch (e) {}
    if (id == null) return null;

    return Get.find<ChatxService>().getKeyPairBySignalId(id);
  }

  Identity getIdentity() {
    return Get.find<HomeController>().allIdentities[identityId]!;
  }

  SignalId? getMySignalId() {
    if (signalIdPubkey == null) return null;

    final res = DBProvider.database.signalIds
        .filter()
        .pubkeyEqualTo(signalIdPubkey!)
        .identityIdEqualTo(identityId)
        .findFirstSync();
    return res;
  }

  SignalId getGroupSharedSignalId() {
    if (sharedSignalID == null) throw Exception('signalId is null');

    final res = DBProvider.database.signalIds
        .filter()
        .pubkeyEqualTo(sharedSignalID!)
        .findFirstSync();
    if (res == null) throw Exception('signalId is null');
    return res;
  }

  Future<RoomMember?> getEnableMember(String pubkey) async {
    final database = DBProvider.database;
    return database.roomMembers
        .filter()
        .roomIdEqualTo(id)
        .idPubkeyEqualTo(pubkey)
        .statusEqualTo(UserStatusType.invited)
        .findFirst();
  }

  Future<Map<String, RoomMember>> getMembers() async {
    final map = <String, RoomMember>{};
    final list = await DBProvider.database.roomMembers
        .filter()
        .roomIdEqualTo(id)
        .findAll();
    for (final rm in list) {
      map[rm.idPubkey] = rm;
    }
    return map;
  }

  Future<Map<String, RoomMember>> getEnableMembers() async {
    final map = <String, RoomMember>{};

    final list = await DBProvider.database.roomMembers
        .filter()
        .roomIdEqualTo(id)
        .statusEqualTo(UserStatusType.invited)
        .findAll();
    for (final rm in list) {
      map[rm.idPubkey] = rm;
    }
    return map;
  }

  Future<List<RoomMember>> getNotEnableMembers() async {
    return DBProvider.database.roomMembers
        .filter()
        .roomIdEqualTo(id)
        .not()
        .statusEqualTo(UserStatusType.invited)
        .findAll();
  }

  // inviting + invited
  Future<List<RoomMember>> getActiveMembers() async {
    return DBProvider.database.roomMembers
        .filter()
        .roomIdEqualTo(id)
        .group(
          (q) => q
              .statusEqualTo(UserStatusType.invited)
              .or()
              .statusEqualTo(UserStatusType.inviting),
        )
        .findAll();
  }

  Future<List<RoomMember>> getInvitingMembers() async {
    return DBProvider.database.roomMembers
        .filter()
        .roomIdEqualTo(id)
        .statusEqualTo(UserStatusType.inviting)
        .findAll();
  }

  Future<bool> checkAdminByIdPubkey(String pubkey) async {
    final admin = await getAdmin();
    if (admin == null) return false;
    return admin == pubkey;
  }

  Future<String?> getAdmin() async {
    final database = DBProvider.database;
    if (isMLSGroup) {
      try {
        final info = await MlsGroupService.instance.getGroupExtension(this);
        if (info.admins.isEmpty) {
          return null;
        } else {
          return info.admins[0];
        }
      } catch (e) {
        logger.e('getAdmin error: $e');
        return null;
      }
    }
    final rm = await database.roomMembers
        .filter()
        .roomIdEqualTo(id)
        .isAdminEqualTo(true)
        .findFirst();
    return rm?.idPubkey;
  }

  // metadata
  Future<RoomMember> addMember({
    required String name,
    required String idPubkey,
    required UserStatusType status,
    required DateTime updatedAt,
    required DateTime createdAt,
    String? curve25519PkHex,
    bool isAdmin = false,
  }) async {
    final database = DBProvider.database;

    var rm = await getMemberByIdPubkey(idPubkey);
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

  Future<void> updateAllMember(List<dynamic> list) async {
    final database = DBProvider.database;
    if (list.isEmpty) return;
    await database.writeTxn(() async {
      // await database.roomMembers.filter().roomIdEqualTo(id).deleteAll();
      for (final user in list) {
        user['roomId'] = id;
        final rm = RoomMember.fromJson(user);
        final exist = await database.roomMembers
            .filter()
            .roomIdEqualTo(id)
            .idPubkeyEqualTo(rm.idPubkey)
            .findFirst();
        if (exist != null) {
          if (exist.updatedAt != null && rm.updatedAt != null) {
            if (exist.updatedAt!.isAfter(rm.updatedAt!)) {
              logger.i('Ingore by updatedAt: ${exist.idPubkey}');
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

  Future<void> updateAllMemberTx(List<dynamic> list) async {
    final database = DBProvider.database;
    if (list.isEmpty) return;
    for (final user in list) {
      late RoomMember rm;
      if (user is RoomMember) {
        user.roomId = id;
        rm = user;
      } else {
        user['roomId'] = id;
        rm = RoomMember.fromJson(user);
      }
      final exist = await database.roomMembers
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
    rm.status = UserStatusType.invited;
    if (name != null) rm.name = name;
    await updateMember(rm);
    RoomService.getController(id)?.resetMembers();
  }

  Future<void> updateMember(RoomMember rm) async {
    final database = DBProvider.database;
    await database.writeTxn(() async {
      await database.roomMembers.put(rm);
    });
  }

  Future<void> updateMemberName(String pubkey, String name) async {
    final database = DBProvider.database;

    final rm = await getMemberByIdPubkey(pubkey);
    if (rm == null) return;
    rm.name = name;
    await database.writeTxn(() async {
      await database.roomMembers.put(rm);
    });
  }

  // soft delete
  Future<void> removeMember(String idPubkey) async {
    final database = DBProvider.database;
    final rm = await getMemberByIdPubkey(idPubkey);
    if (rm == null) return;

    await database.writeTxn(() async {
      rm.status = UserStatusType.removed;
      await database.roomMembers.put(rm);
    });
  }

  Future<void> setMemberDisable(RoomMember rm) async {
    final model = await DBProvider.database.roomMembers
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

  Future<void> setMemberDisableByPubkey(String idPubkey) async {
    final model = await DBProvider.database.roomMembers
        .filter()
        .roomIdEqualTo(id)
        .idPubkeyEqualTo(idPubkey)
        .findFirst();
    if (model == null) return;
    await DBProvider.database.writeTxn(() async {
      model.status = UserStatusType.removed;
      await DBProvider.database.roomMembers.put(model);
    });
  }

  String getRoomName() {
    if (type == RoomType.group) {
      return name ?? getPublicKeyDisplay(npub);
    }

    if (contact == null) {
      return name ?? getPublicKeyDisplay(npub);
    }
    return contact!.displayName;
  }

  Future<Map<String, Room>> getEnableMemberRooms() async {
    final memberRooms = <String, Room>{};
    final rms = await getEnableMembers();
    for (final rm in rms.values) {
      if (rm.idPubkey == myIdPubkey) continue;

      final idRoom = await RoomService.instance.getOrCreateRoom(
        rm.idPubkey,
        myIdPubkey,
        RoomStatus.groupUser,
        contactName: rm.name,
      );
      memberRooms[rm.idPubkey] = idRoom;
    }
    return memberRooms;
  }

  Future<RoomMember?> getMemberByIdPubkey(String pubkey) async {
    final member = RoomService.getController(id)?.getMemberByIdPubkey(pubkey);
    if (member != null) {
      return member;
    }
    if (isMLSGroup) {
      final map = await MlsGroupService.instance.getMembers(this);
      return map[pubkey];
    }

    if (isSendAllGroup) {
      return DBProvider.database.roomMembers
          .filter()
          .roomIdEqualTo(id)
          .idPubkeyEqualTo(pubkey)
          .findFirst();
    }
    return null;
  }

  Future<Map<String, Room>> getActiveMemberRooms(Mykey mainMykey) async {
    final memberRooms = <String, Room>{};
    final rms = (await getMembers()).values.toList();
    for (final rm in rms) {
      if (rm.idPubkey == mainMykey.pubkey) continue;

      final idRoom = await RoomService.instance
          .getOrCreateRoom(rm.idPubkey, mainMykey.pubkey, RoomStatus.groupUser);
      memberRooms[rm.idPubkey] = idRoom;
    }
    return memberRooms;
  }

  Future<RoomMember?> getMemberByNostrPubkey(String pubkey) async {
    return DBProvider.database.roomMembers
        .filter()
        .roomIdEqualTo(id)
        .idPubkeyEqualTo(pubkey)
        .findFirst();
  }

  int getDeviceIdForSignal() {
    return type == RoomType.common ? identityId : 10000 + id;
  }

  Future<void> incrMessageCountForMember(RoomMember member) async {
    var changeMember = false;
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

  String getDebugInfo(String error) {
    return '''
$error
Room: $id, ${getRoomName()} $toMainPubkey,
Please reset room's session: Chat Setting-> Security Settings -> Reset Session''';
  }

  BotMessageData? getBotMessagePriceModel() {
    if (botLocalConfig == null) return null;
    BotMessageData? bmd;
    try {
      final Map config = jsonDecode(botLocalConfig!) as Map<String, dynamic>;
      bmd = BotMessageData.fromJson(
        config[MessageMediaType.botPricePerMessageRequest.name],
      );
    } catch (e) {
      return null;
    }
    return bmd;
  }
}

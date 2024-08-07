import 'package:app/controller/home.controller.dart';
import 'package:app/models/models.dart';
import 'package:app/service/chatx.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/utils.dart';
import 'package:equatable/equatable.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:keychat_rust_ffi_plugin/api_signal.dart';

import 'db_provider.dart';

part 'room.g.dart';

enum RoomType {
  common,
  private,
  group,
}

enum GroupType { shareKey, sendAll }

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
  'parentRoom',
  'messageType'
})
// ignore: must_be_immutable
class Room extends Equatable {
  Id id = Isar.autoIncrement;

  @Index(unique: true, composite: [CompositeIndex('identityId')])
  late String toMainPubkey;
  late String npub;

  // their(Bob) signal id pubkey
  String? curve25519PkHex;
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
  final members = IsarLinks<RoomMember>();

  late DateTime createdAt;

  // pin
  bool pin = false;
  DateTime? pinAt;

  // group info
  String? name;
  String? groupRelay;
  bool isMute = false; // mute notification

  bool signalDecodeError = false; // if decode error set: true

  int unReadCount = 0;
  Message? lastMessageModel;
  Contact? contact; // room'contact info
  Room? parentRoom; // for group room

  String? onetimekey;

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

  MessageType get messageType =>
      type == RoomType.common && encryptMode == EncryptMode.nip04
          ? MessageType.nip04
          : MessageType.signal;

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
  KeychatIdentityKeyPair? get keyPair {
    ChatxService chatxService = Get.find<ChatxService>();
    if (signalIdPubkey == null) {
      return chatxService.getKeyPairByIdentity(getIdentity());
    }
    return chatxService.keypairs[signalIdPubkey];
  }

  Identity getIdentity() {
    return Get.find<HomeController>().identities[identityId]!;
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
        ..curve25519PkHex = curve25519PkHex
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
      return getPublicKeyDisplay(npub);
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
}

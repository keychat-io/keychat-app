import 'package:app/global.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/models/identity.dart';
import 'package:app/models/keychat/room_profile.dart';
import 'package:app/models/mykey.dart';
import 'package:app/models/room.dart';
import 'package:app/models/room_member.dart';

import 'package:app/service/notify.service.dart';
import 'package:app/service/signalId.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rustNostr;

class GroupTx {
  static final GroupTx _singleton = GroupTx._internal();
  factory GroupTx() {
    return _singleton;
  }

  GroupTx._internal();

  Future<Mykey> importMykeyTx(
      Identity identity, rustNostr.Secp256k1Account keychain,
      [int? roomId]) async {
    Isar database = DBProvider.database;
    Mykey? mykey = await database.mykeys
        .filter()
        .identityIdEqualTo(identity.id)
        .pubkeyEqualTo(keychain.pubkey)
        .findFirst();
    if (mykey != null) return mykey;
    final newUser = Mykey(
        prikey: keychain.prikey,
        identityId: identity.id,
        pubkey: keychain.pubkey)
      ..roomId = roomId;
    var savedId = await database.mykeys.put(newUser);
    return (await database.mykeys.get(savedId))!;
  }

  Future<Mykey> createMykey(Identity identity, [int? roomId]) async {
    rustNostr.Secp256k1Account keychain = await rustNostr.generateSecp256K1();
    Isar database = DBProvider.database;
    Mykey? mykey = await database.mykeys
        .filter()
        .identityIdEqualTo(identity.id)
        .pubkeyEqualTo(keychain.pubkey)
        .findFirst();
    if (mykey != null) return mykey;
    final newUser = Mykey(
        prikey: keychain.prikey,
        identityId: identity.id,
        pubkey: keychain.pubkey)
      ..roomId = roomId;
    late Mykey savedMykey;
    await database.writeTxn(() async {
      var savedId = await database.mykeys.put(newUser);
      savedMykey = (await database.mykeys.get(savedId))!;
    });
    return savedMykey;
  }

  Future<Room> _createGroupToDB(String toMainPubkey, String groupName,
      {List<dynamic> members = const [],
      required GroupType groupType,
      required Identity identity,
      required int version,
      Mykey? sharedKey,
      String? groupRelay,
      String? sharedSignalID}) async {
    Room room = Room(
        toMainPubkey: toMainPubkey,
        npub: rustNostr.getBech32PubkeyByHex(hex: toMainPubkey),
        identityId: identity.id,
        status: RoomStatus.enabled,
        type: RoomType.group)
      ..mykey.value = sharedKey
      ..name = groupName
      ..groupType = groupType
      ..version = version
      ..groupRelay = groupRelay
      ..sharedSignalID = sharedSignalID;

    room = await updateRoom(room, updateMykey: true);
    await room.updateAllMemberTx(members);
    RoomMember? me = await room.getMember(identity.secp256k1PKHex);

    if (me != null && me.status != UserStatusType.invited) {
      me.status = UserStatusType.invited;
      await DBProvider.database.roomMembers.put(me);
    }
    if (room.isShareKeyGroup || room.isKDFGroup) {
      await Get.find<WebsocketService>()
          .listenPubkey([toMainPubkey], limit: 300);
      NotifyService.addPubkeys([toMainPubkey]);
    }
    return room;
  }

  Future<Room> updateRoom(Room room, {bool updateMykey = false}) async {
    await DBProvider.database.rooms.put(room);
    if (updateMykey) {
      await room.mykey.save();
    }
    return room;
  }

  Future joinGroup(RoomProfile roomProfile, Identity identity) async {
    String? toRoomPriKey = roomProfile.prikey;
    String groupName = roomProfile.name;
    String groupRelay = roomProfile.groupRelay ?? KeychatGlobal.defaultRelay;
    int version =
        roomProfile.updatedAt ?? DateTime.now().millisecondsSinceEpoch;
    List<dynamic> users = roomProfile.users;
    Mykey? roomKey;
    if ((roomProfile.groupType == GroupType.shareKey ||
            roomProfile.groupType == GroupType.kdf) &&
        toRoomPriKey == null) {
      throw Exception('Prikey is null, failed to join group.');
    } else if (toRoomPriKey != null) {
      roomKey = await importMykeyTx(
          identity, await rustNostr.importKey(senderKeys: toRoomPriKey));
    }

    Room groupRoom = await _createGroupToDB(
        roomProfile.oldToRoomPubKey ?? roomProfile.pubkey, groupName,
        sharedKey: roomKey,
        members: users,
        identity: identity,
        groupType: roomProfile.groupType,
        version: version,
        groupRelay: groupRelay,
        sharedSignalID: roomProfile.signalPubkey);

    // import signalId for kdf group
    if (groupRoom.isKDFGroup && roomProfile.signalPubkey != null) {
      await SignalIdService.instance
          .importSignalId(groupRoom.identityId, roomProfile);
    }
    return groupRoom;
  }
}

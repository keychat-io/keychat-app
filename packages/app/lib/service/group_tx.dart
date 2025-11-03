import 'package:app/models/db_provider.dart';
import 'package:app/models/identity.dart';
import 'package:app/models/keychat/room_profile.dart';
import 'package:app/models/message.dart';
import 'package:app/models/mykey.dart';
import 'package:app/models/room.dart';
import 'package:app/models/room_member.dart';
import 'package:app/service/signalId.service.dart';
import 'package:isar_community/isar.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

class GroupTx {
  // Avoid self instance
  GroupTx._();
  static GroupTx? _instance;
  static GroupTx get instance => _instance ??= GroupTx._();

  Future<Mykey> importMykeyTx(
      int identityId, rust_nostr.Secp256k1Account keychain,
      [int? roomId]) async {
    final database = DBProvider.database;
    final mykey = await database.mykeys
        .filter()
        .identityIdEqualTo(identityId)
        .pubkeyEqualTo(keychain.pubkey)
        .findFirst();
    if (mykey != null) return mykey;
    final newUser = Mykey(
        prikey: keychain.prikey,
        identityId: identityId,
        pubkey: keychain.pubkey)
      ..roomId = roomId;
    final savedId = await database.mykeys.put(newUser);
    return (await database.mykeys.get(savedId))!;
  }

  Future<Room> _createGroupToDB(String toMainPubkey, String groupName,
      {required GroupType groupType,
      required Identity identity,
      required int version,
      List<dynamic> members = const [],
      int? roomUpdateAt,
      Mykey? sharedKey,
      List<String> sendingRelays = const [],
      String? sharedSignalID}) async {
    var room = Room(
        toMainPubkey: toMainPubkey,
        npub: rust_nostr.getBech32PubkeyByHex(hex: toMainPubkey),
        identityId: identity.id,
        type: RoomType.group)
      ..mykey.value = sharedKey
      ..name = groupName
      ..groupType = groupType
      ..sendingRelays = sendingRelays
      ..version = version
      ..sharedSignalID = sharedSignalID;

    room = await updateRoom(room, updateMykey: true);
    await room.updateAllMemberTx(members);
    final me = await room.getMemberByIdPubkey(identity.secp256k1PKHex);

    if (me != null && me.status != UserStatusType.invited) {
      me.status = UserStatusType.invited;
      await DBProvider.database.roomMembers.put(me);
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

  Future<Room> joinGroup(RoomProfile roomProfile, Identity identity,
      [Message? message]) async {
    final toMainPubkey = roomProfile.oldToRoomPubKey ?? roomProfile.pubkey;
    final toRoomPriKey = roomProfile.prikey;
    final version = roomProfile.updatedAt;
    final users = roomProfile.users;
    Mykey? roomKey;
    if (toRoomPriKey != null) {
      roomKey = await importMykeyTx(
          identity.id, await rust_nostr.importKey(senderKeys: toRoomPriKey));
    }

    final groupRoom = await _createGroupToDB(toMainPubkey, roomProfile.name,
        sharedKey: roomKey,
        members: users,
        identity: identity,
        groupType: roomProfile.groupType,
        version: version,
        sharedSignalID: roomProfile.signalPubkey,
        roomUpdateAt: roomProfile.updatedAt);

    // import signalId for kdf group
    if (groupRoom.isKDFGroup && roomProfile.signalPubkey != null) {
      if (message != null) {
        message.content = '******';
        await DBProvider.database.messages.put(message);
      }
      await SignalIdService.instance
          .importOrGetSignalId(groupRoom.identityId, roomProfile);
    }
    return groupRoom;
  }
}

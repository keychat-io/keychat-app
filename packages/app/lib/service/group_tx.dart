import 'package:keychat/models/db_provider.dart';
import 'package:keychat/models/identity.dart';
import 'package:keychat/models/keychat/room_profile.dart';
import 'package:keychat/models/message.dart';
import 'package:keychat/models/mykey.dart';
import 'package:keychat/models/room.dart';
import 'package:keychat/models/room_member.dart';
import 'package:keychat/service/signalId.service.dart';
import 'package:isar_community/isar.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

/// Handles group-related database transactions that must run atomically.
///
/// All write operations in this class are designed to be executed within
/// an Isar [writeTxn] block to ensure consistency.
class GroupTx {
  // Avoid self instance
  GroupTx._();
  static GroupTx? _instance;
  static GroupTx get instance => _instance ??= GroupTx._();

  /// Imports or retrieves a [Mykey] record for the given [keychain].
  ///
  /// Looks up an existing key by [identityId] and public key. If not found,
  /// creates and persists a new [Mykey] record. Optionally associates it with
  /// [roomId].
  ///
  /// Returns the persisted [Mykey] instance.
  Future<Mykey> importMykeyTx(
    int identityId,
    rust_nostr.Secp256k1Account keychain, [
    int? roomId,
  ]) async {
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
      pubkey: keychain.pubkey,
    )..roomId = roomId;
    final savedId = await database.mykeys.put(newUser);
    return (await database.mykeys.get(savedId))!;
  }

  // Creates the room record and initializes the member list within a transaction.
  // Must be called from within an Isar writeTxn block.
  Future<Room> _createGroupToDB(
    String toMainPubkey,
    String groupName, {
    required GroupType groupType,
    required Identity identity,
    required int version,
    List<dynamic> members = const [],
    int? roomUpdateAt,
    Mykey? sharedKey,
    List<String> sendingRelays = const [],
    String? sharedSignalID,
  }) async {
    var room =
        Room(
            toMainPubkey: toMainPubkey,
            npub: rust_nostr.getBech32PubkeyByHex(hex: toMainPubkey),
            identityId: identity.id,
            type: RoomType.group,
          )
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

  /// Persists [room] to the database.
  ///
  /// If [updateMykey] is `true`, also saves the associated [Mykey] link.
  /// Returns the updated [Room] instance.
  Future<Room> updateRoom(Room room, {bool updateMykey = false}) async {
    await DBProvider.database.rooms.put(room);
    if (updateMykey) {
      await room.mykey.save();
    }
    return room;
  }

  /// Joins a group from a received [RoomProfile] invitation.
  ///
  /// Imports the shared room private key (if present), creates the group
  /// room via [_createGroupToDB], and sets up the member list from
  /// [roomProfile.users]. For KDF groups that include a Signal pubkey,
  /// also imports the Signal identity via [SignalIdService].
  ///
  /// Optionally updates [message] content to hide the raw private key
  /// before it is persisted.
  ///
  /// Returns the newly created [Room].
  Future<Room> joinGroup(
    RoomProfile roomProfile,
    Identity identity, [
    Message? message,
  ]) async {
    final toMainPubkey = roomProfile.oldToRoomPubKey ?? roomProfile.pubkey;
    final toRoomPriKey = roomProfile.prikey;
    final version = roomProfile.updatedAt;
    final users = roomProfile.users;
    Mykey? roomKey;
    if (toRoomPriKey != null) {
      roomKey = await importMykeyTx(
        identity.id,
        await rust_nostr.importKey(senderKeys: toRoomPriKey),
      );
    }

    final groupRoom = await _createGroupToDB(
      toMainPubkey,
      roomProfile.name,
      sharedKey: roomKey,
      members: users,
      identity: identity,
      groupType: roomProfile.groupType,
      version: version,
      sharedSignalID: roomProfile.signalPubkey,
      roomUpdateAt: roomProfile.updatedAt,
    );

    // import signalId for kdf group
    if (groupRoom.isKDFGroup && roomProfile.signalPubkey != null) {
      if (message != null) {
        message.content = '******';
        await DBProvider.database.messages.put(message);
      }
      await SignalIdService.instance.importOrGetSignalId(
        groupRoom.identityId,
        roomProfile,
      );
    }
    return groupRoom;
  }
}

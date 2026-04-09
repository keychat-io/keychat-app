const String appDefaultTitle = 'Keychat';
const String nip04MessageKeyword = '?iv=';

int gDefaultNumWaitSeconds = 5000; // is used in main()
int waitContactSeconds = 5000; // is used in main()

class NostrResponseKinds {
  static const String notice = 'NOTICE';
  static const String ok = 'OK';
  static const String auth = 'AUTH';
  static const String eose = 'EOSE';
  static const String event = 'EVENT';
}

/// Application-level message type constants used inside the encrypted payload.
///
/// These are NOT Nostr event kinds. They live inside the decrypted message body
/// (`KeychatMessage.type` / GroupMessage.subtype) to distinguish different
/// application-level operations within a single Nostr event.
class KeyChatEventKinds {
  // ── Signal 1:1 ──

  /// Regular direct message, may contain reply metadata in `name` field.
  static const int dm = 100;

  /// X3DH handshake: sender initiates encrypted session with key exchange data.
  static const int dmAddContactFromAlice = 101;

  /// Reject a friend request / handshake.
  static const int dmReject = 104;

  /// Invite the recipient to sync relay configuration.
  static const int signalRelaySyncInvite = 45;

  /// Send sender's profile (name, avatar, lightning, bio) to the recipient.
  static const int signalSendProfile = 48;

  // ── Signal Group (sendAll) ──

  /// Admin sends group invitation with RoomProfile to a contact.
  static const int groupInvite = 11;

  /// New member join greeting (legacy, kept for backward compatibility).
  @Deprecated('not used')
  static const int groupHi = 14;

  /// Member changes their nickname within the group.
  static const int groupChangeNickname = 15;

  /// Member voluntarily leaves the group.
  static const int groupSelfLeave = 16;

  /// Admin dissolves the entire group.
  static const int groupDissolve = 17;

  /// Admin changes the group name.
  static const int groupChangeRoomName = 20;

  /// Broadcast message envelope: wraps a GroupMessage sent to all members.
  static const int groupSendToAllMessage = 30;

  /// Admin removes a single member from the group.
  static const int groupRemoveSingleMember = 32;

  /// Non-admin member requests to invite a contact into the group via admin.
  static const int inviteToGroupRequest = 3005;

  // ── MLS Group ──

  /// Share MLS group invitation info with a contact (1:1 channel).
  static const int groupInvitationInfo = 3008;

  /// Request to join an MLS group (kept for melos compatibility).
  static const int groupInvitationRequesting = 3009;
}

class EventKindTags {
  static const String customMessage = 'm';
  static const String event = 'e';
  static const String pubkey = 'p';
  // static const String nip104Group = 'h';
  static const String delegation = 'delegation';
  static const String deduplication = 'd';
  static const String expiration = 'expiration';
}

class EventKinds {
  static const int setMetadata = 0;
  static const int textNote = 1;
  static const int recommendServer = 2;
  static const int contactList = 3;
  static const int nip04 = 4;
  static const int delete = 5;
  static const int reaction = 7;
  static const int nip42 = 22242;
  static const int chatRumor = 14; // NIP-17 inner rumor (chat message)
  static const int nip17 = 1059; // NIP-17 outer gift wrap
  static const int nwcRequest = 23194;
  static const int nwcResponse = 23195;
  // static const int nip104KP = 443;
  // static const int nip104RelaysListEvent = 10051;
  static const int mlsNipKeypackages = 10443;
  static const int mlsNipWelcome = 444;
  // static const int nip104GroupEvent = 445;

  // Channels
  // CHANNEL_CREATION = 40;
  // CHANNEL_METADATA = 41;
  // CHANNEL_MESSAGE = 42;
  // CHANNEL_HIDE_MESSAGE = 43;
  // CHANNEL_MUTE_USER = 44;
  // CHANNEL_RESERVED_FIRST = 45;
  // CHANNEL_RESERVED_LAST = 49;
  // Relay-only
  // RELAY_INVITE = 50;
  // INVOICE_UPDATE = 402;
  // // Replaceable events
  // REPLACEABLE_FIRST = 10000;
  // REPLACEABLE_LAST = 19999;
  // // Ephemeral events
  // EPHEMERAL_FIRST = 20000;
  // EPHEMERAL_LAST = 29999;
  // // Parameterized replaceable events
  // PARAMETERIZED_REPLACEABLE_FIRST = 30000;
  // PARAMETERIZED_REPLACEABLE_LAST = 39999;
  // USER_APPLICATION_FIRST = 40000;
  // USER_APPLICATION_LAST = Number.MAX_SAFE_INTEGER;
}

// enum EventTags {
//   Event = 'e';
//   Pubkey = 'p';
//   //  Multicast = 'm';
//   Delegation = 'delegation';
//   Deduplication = 'd';
//   Expiration = 'expiration';
// }

// enum PaymentsProcessors {
//   LNURL = 'lnurl';
//   ZEBEDEE = 'zebedee';
//   LNBITS = 'lnbits';
// }

class MessageInfo {
  static String resetSessionRequst =
      '[System] Try to reset encrypt session status';
  static String resetSessionSuccess = '[System] Reset successfully';
}

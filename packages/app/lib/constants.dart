const String appDefaultTitle = 'Keychat';
const String nip04MessageKeyword = '?iv=';

int gDefaultNumWaitSeconds = 5000; // is used in main()
int waitContactSeconds = 5000; // is used in main()

class NostrResKinds {
  static const String notice = 'NOTICE';
  static const String ok = 'OK';
  static const String auth = 'AUTH';
  static const String eose = 'EOSE';
  static const String event = 'EVENT';
}

class KeyChatEventKinds {
  static const int start = 1; // default
  static const int dm = 100; // one to one private chat
  static const int dmAddContactFromAlice = 101; // request to add friend
  static const int dmAddContactFromBob = 102; // agree to add friend
  static const int dmDeleteHistory = 103; // delete history
  static const int dmReject = 104; // reject to add friend
  static const int dmEnd = 200; // chat end

  // share key group
  static const int groupInvite = 11;
  static const int groupSharedKeyMessage = 12;
  static const int groupHi = 14;
  static const int groupChangeNickname = 15;
  static const int groupSelfLeave = 16;
  static const int groupDissolve = 17;
  static const int groupSyncMembers = 18;
  static const int groupChangeSignKey =
      19; //  update shared key or delete room meber
  static const int groupChangeRoomName = 20;
  static const int groupSendToAllMessage = 30; // send message to all
  static const int groupRemoveMember = 31; // remove room member
  static const int groupRemoveSingleMember = 32; // remove single room member
  static const int groupSelfLeaveConfirm = 33; // confirm to remove member

  static const int groupShreKeyEnd = 39;

  static const int signal = 40;
  static const int signalInvite = 41;
  static const int signalInviteReply = 42;
  static const int signalInviteReply2 = 43;
  // static const int signalDM = 44;
  static const int signalRelaySyncInvite = 45;
  static const int signalRelaySyncConfirm = 46;
  static const int signalRelaySyncRefuse = 47;

  // > 2000, common proccess
  // WebRTC
  static const int webrtcVideoCall = 2001; // video call
  static const int webrtcAudioCall = 2002; // audio call
  static const int webrtcSignaling = 2003; // candidate, offer, answer
  static const int webrtcCancel = 2004; // cancel call when waiting page
  static const int webrtcReject = 2005;
  static const int webrtcEnd = 2006;

  // kdf group
  static const int groupHelloMessage = 3001;
  static const int groupWelcomeMessage = 3002;
  static const int inviteNewMember = 3004;
  static const int inviteToGroupRequest = 3005;
  static const int groupUpdateKeys = 3006;
  static const int groupAdminRemoveMembers = 3007;
}

class EventKinds {
  static const int setMetadata = 0;
  static const int textNote = 1;
  static const int recommendServer = 2;
  static const int contactList = 3;
  static const int encryptedDirectMessage = 4;
  static const int delete = 5;
  static const int reaction = 7;
  static const int nip42 = 22242;
  static const int nip17 = 1059;
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
  static String resetSessionRequst = '🤖 Try to reset encrypt session status';
  static String resetSessionSuccess = '🤖 Reset successfully';
}

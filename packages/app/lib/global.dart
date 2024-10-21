library keychat.global;

class KeychatGlobal {
  static const String bot = 'Bot';
  static const String selfName = 'Note to Self';
  static const String search = 'SEARCH';
  static const String recommendRooms = 'recommendRooms';
  static const int remainReceiveKeyPerRoom = 2;
  static const String baseFilePath = 'file';
  static const String signalProcotolDBFile = 'signal_procotol.db';
  static const String ecashDBFile = 'ecash.db';
  static const String notifycationServer = 'https://notify.keychat.io/v2';
  static const int cashuPrepareAmount = 32;
  static const int messageFailedAfterSeconds = 4;
  static const String defaultCashuMintURL = 'https://8333.space:3338/';
  // token: /api/v1/object, fee: /api/v1/info
  static const String defaultFileServer = 'wss://relay.keychat.io';
  static const Set<String> skipFileServers = {
    'wss://relay.damus.io',
    'wss://nos.lol',
    'wss://relay.primal.net'
  };

  static const String defaultRelay = 'wss://relay.keychat.io';
  static const int oneTimePubkeysPoolLength = 1;
  static const int signalIdsPoolLength = 1;
  static const int oneTimePubkeysLifetime = 24; // hours
  static const int signalIdLifetime = 168; // hours
  static const List webrtcIceServers = [
    {'url': 'stun:stun.l.google.com:19302'},
    {'url': 'stun:stun1.l.google.com:19302'},
    {'url': 'stun:stun.keychat.io:3478'},
    {
      'url': 'turn:stun.keychat.io:3478',
      'username': 'keychat',
      'credential': 'nostrecash'
    },
    {'url': 'stun:freeturn.net:3478'},
    {'url': 'turn:freeturn.net:3478', 'username': 'free', 'credential': 'free'},
    {'urls': 'stun:freeturn.net:5349'},
    {
      'urls': 'turns:freeturn.tel:5349',
      'username': 'free',
      'credential': 'free'
    },
  ];
  static const List<String> keychatIntros = [
    'Keychat is a chat app, built on Bitcoin ecash, Nostr protocol and Signal protocol.',
    'Keychat is inspired by the postal system — stamps, post offices, letters.',
    'Keychat uses Bitcoin ecash as stamps and Nostr relays as post offices.',
    'Keychat uses Signal protocol to ensure message encryption security and meta-data privacy.'
  ];
  static const String keychatIntro2 =
      '''Keychat is a chat app, built on Bitcoin ecash, Nostr protocol and Signal protocol.

Keychat is inspired by the postal system — stamps, post offices, letters.

Keychat uses Bitcoin ecash as stamps and Nostr relays as post offices. 

Senders send messages stamped with Bitcoin ecash to Nostr relays. The Nostr relays collect the Bitcoin ecash, then deliver messages to receivers. 

Unlike the centralized postal system, Keychat can use multiple Bitcoin ecash issuers and Nostr relays, each maintained by distinct operators.

Keychat uses Signal protocol to ensure message encryption security and meta-data privacy.

The content of the letter can be exposed easily by opening the envelope. Keychat messages are end-to-end encrypted via Signal protocol, with a unique encryption key generated for each message. Only the sender and receiver can decrypt the message.

The addresses of both parties on the envelope can be tracked. In theory, this problem is solved if they change addresses daily. So Keychat reuses Signal protocol to update sending and receiving addresses for nearly every message.

Like the postal system, Keychat requires no registration. Users just generate Nostr keys as ID.''';

  static int kdfGroupPrekeyMessageCount = 3;
  static int kdfGroupKeysExpired = 7;
}

import 'dart:ui' show Color;

class KeychatGlobal {
  static const Color primaryColor = Color(0xff7748FF); // 0xff8700ED
  static const Color secondaryColor = Color(0xff7748FF);
  static const String appName = 'Keychat';
  static const String newTab = 'New Tab';
  static const String appPackageName = 'com.keychat.io';
  static const String bot = 'Bot';
  static const String selfName = 'Note to Self';
  static const String search = 'SEARCH';
  static const String recommendRooms = 'recommendRooms';
  static const int remainReceiveKeyPerRoom = 2;
  static const String baseFilePath = 'file';
  static const String signalProcotolDBFile = 'signal_procotol.db';
  static const String ecashDBFileV1 = 'ecash.db';
  static const String ecashDBFileV2 = 'ecash_v2.db';
  static const String mlsDBFile = 'mls.db3';
  static const String notifycationServer = 'https://notify.keychat.io/v2';
  static const String mainWebsite = 'https://www.keychat.io';
  static const int cashuPrepareAmount = 32;
  static const int messageFailedAfterSeconds = 3;
  static const String defaultCashuMintURL =
      'https://mint.minibits.cash/Bitcoin';
  // token: /api/v1/object, fee: /api/v1/info
  static const String defaultFileServer = 'https://relay.keychat.io';
  static const String defaultRelay = 'wss://relay.keychat.io';

  static const int oneTimePubkeysPoolLength = 1;
  static const int signalIdsPoolLength = 1;
  static const int oneTimePubkeysLifetime = 24; // hours
  static const int signalIdLifetime = 168; // hours
  static const webrtcIceServers = [
    {'url': 'stun:stun.l.google.com:19302'},
    {'url': 'stun:stun1.l.google.com:19302'},
    {'url': 'stun:stun.keychat.io:3478'},
    {
      'url': 'turn:stun.keychat.io:3478',
      'username': 'keychat',
      'credential': 'nostrecash',
    },
    {'url': 'stun:freeturn.net:3478'},
    {'url': 'turn:freeturn.net:3478', 'username': 'free', 'credential': 'free'},
    {'urls': 'stun:freeturn.net:5349'},
    {
      'urls': 'turns:freeturn.tel:5349',
      'username': 'free',
      'credential': 'free',
    },
  ];
  static const List<String> keychatIntros = [
    'Keychat is the super app for Bitcoiners.',
    'Autonomous IDs, Bitcoin ecash wallet, secure chat, and rich Mini Apps — all in Keychat.',
    'Autonomy. Security. Richness.',
  ];

  static int kdfGroupPrekeyMessageCount = 3;
  static int kdfGroupKeysExpired = 7;
  static String browserConfig = 'browserConfig';
  static String browserTextSize = 'browserTextSize';
}

// for desktop nest routing
class GetXNestKey {
  static int room = 1;
  static int browser = 2;
  static int setting = 3;
  static int ecash = 4;
}

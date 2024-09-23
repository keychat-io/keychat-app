import 'package:app/global.dart';
import 'package:app/models/embedded/relay_file_fee.dart';
import 'package:app/models/embedded/relay_message_fee.dart';
import 'package:app/nostr-core/relay_websocket.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/storage.dart';

import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:app/utils/config.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:app/models/models.dart';

import '../models/db_provider.dart';
import 'identity.service.dart';

class RelayService {
  static final RelayService _singleton = RelayService._internal();
  static final DBProvider dbProvider = DBProvider();
  static final IdentityService identityService = IdentityService();

  factory RelayService() {
    return _singleton;
  }

  RelayService._internal();

  Future addAndConnect(String url) async {
    WebsocketService ws = Get.find<WebsocketService>();
    if (ws.channels[url] != null) return;

    Relay relay = await RelayService().getOrPutRelay(url);
    ws.addChannel(relay);
    NotifyService.syncPubkeysToServer(); // sub new relay
    RelayService().initRelayFeeInfo([relay]);
  }

  Future<Relay> add(String url, [bool isDefault = false]) async {
    Isar database = DBProvider.database;
    final relay = Relay(url);
    await database.writeTxn(() async {
      relay.isDefault = isDefault;
      await database.relays.put(relay);
    });
    return relay;
  }

  Future<Relay> getOrPutRelay(String url) async {
    Isar database = DBProvider.database;

    Relay? r = await database.relays.filter().urlEqualTo(url).findFirst();
    if (r == null) {
      Relay relay = Relay(url);

      int? id = await database.writeTxn(() async {
        return await database.relays.put(relay);
      });
      r = await database.relays.get(id!);
    }
    if (r == null) throw Exception('getOrPutRelay error');
    return r;
  }

  // Future<List<Relay>> getReadList() async {
  //   return (await _DBProvider.database)
  //       .relays
  //       .filter()
  //       .readEqualTo(true)
  //       .activeEqualTo(true)
  //       .findAll();
  // }

  // Future<List<Relay>> getWriteList() async {
  //   return (await _DBProvider.database)
  //       .relays
  //       .filter()
  //       .writeEqualTo(true)
  //       .activeEqualTo(true)
  //       .findAll();
  // }

  delete(int id) async {
    Isar database = DBProvider.database;

    return await database.writeTxn(() async {
      return await database.relays.delete(id);
    });
  }

  Future<List<Relay>> list() async {
    List<Relay> list = await DBProvider.database.relays.where().findAll();

    Map<String, Relay> newList = {};
    for (Relay relay in list) {
      newList[relay.url] = relay;
    }
    return newList.values.toList();
  }

  Future<List<String>> getEnableList() async {
    List<Relay> list =
        await DBProvider.database.relays.filter().activeEqualTo(true).findAll();

    Set<String> newList = {};
    for (Relay relay in list) {
      newList.add(relay.url);
    }
    return newList.toList();
  }

  Future<List<Relay>> getEnableRelays() async {
    List<Relay> list =
        await DBProvider.database.relays.filter().activeEqualTo(true).findAll();

    return list;
  }

  Future<int> count() async {
    return await DBProvider.database.relays.where().count();
  }

  Future<void> updateReadWrite(
      {required int id,
      required bool read,
      required bool write,
      required bool active}) async {
    Isar database = DBProvider.database;

    await database.writeTxn(() async {
      final relay = await database.relays.get(id);
      if (relay != null) {
        relay.read = read;
        relay.write = write;
        relay.active = active;
        relay.errorMessage = null;

        await database.relays.put(relay);
      }
    });
  }

  Future<void> updateStatus(
      {required Relay relay, DateTime? updatedAt, String? errorMessage}) async {
    Isar database = DBProvider.database;

    try {
      await database.writeTxn(() async {
        relay.errorMessage = errorMessage;
        if (updatedAt != null) {
          relay.updatedAt = DateTime.now();
        }
        await database.relays.put(relay);
      });
    } catch (e) {
      logger.i('updateStatus error: $e');
    }
  }

  Future update(Relay relay) async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.relays.put(relay);
    });
  }

  Future updateDefault(Relay relay, bool afterValue) async {
    await DBProvider.database.writeTxn(() async {
      if (afterValue) {
        await DBProvider.database.relays
            .filter()
            .isDefaultEqualTo(true)
            .findAll()
            .then((value) async {
          for (Relay r in value) {
            r.isDefault = false;
            await DBProvider.database.relays.put(r);
          }
        });
      }
      relay.isDefault = afterValue;
      await DBProvider.database.relays.put(relay);
    });
  }

  Future checkDefaultRelay(List<Relay> relays) async {
    for (Relay r in relays) {
      if (r.isDefault) {
        return relays;
      }
    }
    Relay? defaultRelay = relays.firstWhereOrNull(
        (element) => element.url == KeychatGlobal.defaultRelay);
    if (defaultRelay == null) {
      var relay = await add(KeychatGlobal.defaultRelay);
      relays.add(relay);
      return relays;
    }
    defaultRelay.isDefault = true;
    await update(defaultRelay);
    relays.removeWhere((element) => element.url == defaultRelay.url);
    relays.add(defaultRelay);
    return relays;
  }

  Future<Map<String, dynamic>?> fetchRelayNostrInfo(Relay relay) async {
    Dio dio = Dio();
    try {
      late String url;
      if (relay.url.startsWith('ws://')) {
        url = relay.url.replaceFirst('ws://', 'http://');
      }
      if (relay.url.startsWith('wss://')) {
        url = relay.url.replaceFirst('wss://', 'https://');
      }
      if (url.isEmpty) return null;

      final res = await dio.get(url,
          options: Options(
              headers: {"Accept": "application/nostr+json"},
              sendTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10)));
      return res.data;
    } on DioException catch (e, s) {
      String? msg = e.response?.data;
      logger.e('relay faild: ${relay.url} , $msg', stackTrace: s);
    } catch (e, s) {
      logger.e('relay faild: ${relay.url} , $e', stackTrace: s);
    }
    return null;
  }

  Future initRelayFeeInfo([List<Relay>? relays]) async {
    try {
      try {
        Get.find<WebsocketService>();
      } catch (e) {
        // skip if websocket not init
        return;
      }
      await RelayService().fetchRelayMessageFee(relays);
      await RelayService().fetchRelayFileFee(relays);
    } catch (e, s) {
      logger.e(e.toString(), stackTrace: s);
    }
  }

  /// get a online relay and it is the default setting
  Future<String?> getDefaultOnlineRelay() async {
    Relay? relay = await DBProvider.database.relays
        .filter()
        .isDefaultEqualTo(true)
        .findFirst();
    if (relay != null) return relay.url;

    RelayWebsocket? rw =
        Get.find<WebsocketService>().channels[KeychatGlobal.defaultRelay];
    if (rw != null) KeychatGlobal.defaultRelay;

    List<String> relays = Get.find<WebsocketService>().channels.keys.toList();
    return relays.first;
  }

  Future<Relay?> getDefault() async {
    return await DBProvider.database.relays
        .filter()
        .isDefaultEqualTo(true)
        .findFirst();
  }

  Future<List<Relay>> initRelay() async {
    Isar database = DBProvider.database;
    List<Relay> list = await RelayService().list();
    if (list.isEmpty) {
      await database.writeTxn(() async {
        for (var url in Config.getEnvConfig('nostrRelays')) {
          final relay = Relay(url);
          await database.relays.put(relay);
        }
      });
      list = await RelayService().list();
    }
    // list = await checkDefaultRelay(list);
    return list;
  }

  Future fetchRelayMessageFee([List<Relay>? relays]) async {
    WebsocketService ws = Get.find<WebsocketService>();
    relays ??= await getEnableRelays();
    for (Relay relay in relays) {
      try {
        if (relay.errorMessage != null) {
          relay.errorMessage = null;
          update(relay);
        }

        RelayMessageFee? payInfo = await _fetchCashuPayInfo(relay);
        // logger.i('fetchRelayMessageFee, $relay: $payInfo');
        if (payInfo != null) {
          ws.relayMessageFeeModels[relay.url] = payInfo;
          // logger.d('_fetchCashuPayInfo: ${payInfo.amount} ${payInfo.mints}');
          ws.relayMessageFeeModels.refresh();
        }
      } catch (e, s) {
        logger.e(e.toString(), error: e, stackTrace: s);
      }
    }
    // store to local
    await Storage.setLocalStorageMap(
        StorageKeyString.relayMessageFeeConfig, ws.relayMessageFeeModels);
  }

  Future fetchRelayFileFee([List<Relay>? relays]) async {
    WebsocketService ws = Get.find<WebsocketService>();
    relays ??= await getEnableRelays();
    for (Relay relay in relays) {
      RelayFileFee? fuc = await initRelayFileFeeModel(relay.url);
      // logger.i('initRelayFileFeeModel, $relay: ${fuc.toString()}');
      if (fuc != null) {
        ws.relayFileFeeModels[relay.url] = fuc;
      }
    }
    // store to local
    await Storage.setLocalStorageMap(
        StorageKeyString.relayFileFeeConfig, ws.relayFileFeeModels);
  }

  // curl -H "Accept: application/nostr+json" https://relay.keychat.io
  Future<RelayMessageFee?> _fetchCashuPayInfo(Relay relay) async {
    Map? data = await fetchRelayNostrInfo(relay);
    if (data == null || data.isEmpty) return null;
    if (data['limitation'] != null) {
      if (data['limitation']['payment_required'] ?? false) {
        Map fees = data["fees"] ?? {};
        for (var map in fees.entries) {
          if (map.key == 'publication') {
            if (map.value.length == 0) continue;
            Map publication = fees['publication'][0];
            if (publication['method'] != null) {
              List<String> mints = [];
              for (var m in publication['method']['Cashu']["mints"]) {
                mints.add(m);
              }

              RelayMessageFee payInfo = RelayMessageFee()
                ..amount = publication['amount']
                ..unit = RelayMessageFee.getSymbolByName(publication['unit'])
                ..mints = mints;

              return payInfo;
            }
          }
        }
      }
    }
    return null;
  }

  // curl https://backup.keychat.io/api/v1/info
  // {"maxsize":104857600,"mints":["https://8333.space:3338"],"prices":[{"max":10485760,"min":1,"price":1},{"max":104857600,"min":10485761,"price":2}],"unit":"sat"}
  Future<Map?> _fetchFileUploadConfig(String url) async {
    if (url.startsWith('wss://')) {
      url = url.replaceFirst('wss://', 'https://');
    }
    if (url.startsWith('ws://')) {
      url = url.replaceFirst('ws://', 'http://');
    }
    final dio = Dio();
    dio.options = BaseOptions(
        headers: {'Content-Type': 'application/json'},
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
        sendTimeout: const Duration(seconds: 6));
    try {
      var response = await dio.get('$url/api/v1/info');

      if (response.statusCode == 200 && response.data is Map) {
        return response.data;
      } else {
        loggerNoLine.e(
            'Failed to fetch file server info. Error: ${response.statusCode}');
      }
    } catch (e) {
      loggerNoLine.e('Failed to fetch file server info', error: e);
    }

    return null;
  }

  Future<RelayFileFee?> initRelayFileFeeModel(String url) async {
    if (KeychatGlobal.skipFileServers.contains(url)) return null;
    try {
      Map? map = await _fetchFileUploadConfig(url);
      logger.d('fetchAndSetFileUploadConfig, $url: $map');
      if (map != null) {
        RelayFileFee rufc = RelayFileFee();
        rufc.maxSize = map['maxsize'] ?? 0;
        rufc.mints = map['mints'] ?? [];
        rufc.prices = map['prices'] ?? [];
        rufc.unit = map['unit'] ?? '-';
        rufc.expired = map['expired'] ?? '-';
        return rufc;
      }
    } catch (e) {
      loggerNoLine.e(e.toString());
    }
    return null;
  }
}

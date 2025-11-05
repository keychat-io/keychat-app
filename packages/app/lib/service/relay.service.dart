import 'package:keychat/global.dart';
import 'package:keychat/models/embedded/relay_file_fee.dart';
import 'package:keychat/models/embedded/relay_message_fee.dart';
import 'package:keychat/nostr-core/relay_websocket.dart';
import 'package:keychat/service/mls_group.service.dart';
import 'package:keychat/service/notify.service.dart';
import 'package:keychat/service/storage.dart';

import 'package:keychat/service/websocket.service.dart';
import 'package:keychat/utils.dart';
import 'package:keychat/utils/config.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:isar_community/isar.dart';
import 'package:keychat/models/models.dart';

import 'package:keychat/service/identity.service.dart';

class RelayService {
  // Avoid self instance
  RelayService._();
  static final DBProvider dbProvider = DBProvider.instance;
  static final IdentityService identityService = IdentityService.instance;

  static RelayService? _instance;
  static RelayService get instance => _instance ??= RelayService._();

  Future<bool> addAndConnect(String url) async {
    final ws = Get.find<WebsocketService>();
    final relay = await RelayService.instance.getOrPutRelay(url);

    if (ws.channels[url] != null) {
      if (ws.channels[url]!.isConnected()) return false; // already connected
      ws.channels.remove(url);
    }
    relay.active = true;
    relay.errorMessage = null;
    await update(relay);
    await ws.addChannel(
      relay,
      connectedCallback: () async {
        NotifyService.syncPubkeysToServer(); // sub new relay
        RelayService.instance.initRelayFeeInfo([relay]);
        await MlsGroupService.instance.uploadKeyPackages(toRelay: relay.url);
      },
    );
    return true;
  }

  Future<Relay> add(String url, [bool isDefault = false]) async {
    final database = DBProvider.database;
    final relay = Relay(url);
    await database.writeTxn(() async {
      relay.isDefault = isDefault;
      await database.relays.put(relay);
    });
    return relay;
  }

  Future<Relay> getOrPutRelay(String url) async {
    final database = DBProvider.database;

    var r = await database.relays.filter().urlEqualTo(url).findFirst();
    if (r == null) {
      final relay = Relay(url);

      final id = await database.writeTxn(() async {
        return database.relays.put(relay);
      });
      r = await database.relays.get(id);
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

  Future<bool> delete(int id) async {
    final database = DBProvider.database;

    return database.writeTxn(() async {
      return database.relays.delete(id);
    });
  }

  Future<List<Relay>> list() async {
    final list = await DBProvider.database.relays.where().findAll();

    final newList = <String, Relay>{};
    for (final relay in list) {
      newList[relay.url] = relay;
    }
    return newList.values.toList();
  }

  Future<List<String>> getEnableList() async {
    final list = await DBProvider.database.relays
        .filter()
        .activeEqualTo(true)
        .findAll();

    final newList = <String>{};
    for (final relay in list) {
      newList.add(relay.url);
    }
    return newList.toList();
  }

  Future<List<Relay>> getEnableRelays() async {
    final list = await DBProvider.database.relays
        .filter()
        .activeEqualTo(true)
        .findAll();

    return list;
  }

  Future<int> count() async {
    return DBProvider.database.relays.where().count();
  }

  Future<void> updateReadWrite({
    required int id,
    required bool read,
    required bool write,
    required bool active,
  }) async {
    final database = DBProvider.database;

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

  Future<void> updateStatus({
    required Relay relay,
    DateTime? updatedAt,
    String? errorMessage,
  }) async {
    final database = DBProvider.database;

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

  Future<Relay> updateP104(String relayUrl, bool isEnableNip104) async {
    final relay = await getOrPutRelay(relayUrl);
    relay.isEnableNip104 = isEnableNip104;
    await update(relay);
    Utils.getGetxController<WebsocketService>()
            ?.channels[relayUrl]
            ?.relay
            .isEnableNip104 =
        isEnableNip104;
    return relay;
  }

  Future<void> update(Relay relay) async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.relays.put(relay);
    });
  }

  Future<void> updateDefault(Relay relay, bool afterValue) async {
    await DBProvider.database.writeTxn(() async {
      if (afterValue) {
        await DBProvider.database.relays
            .filter()
            .isDefaultEqualTo(true)
            .findAll()
            .then((value) async {
              for (final r in value) {
                r.isDefault = false;
                await DBProvider.database.relays.put(r);
              }
            });
      }
      relay.isDefault = afterValue;
      await DBProvider.database.relays.put(relay);
    });
  }

  Future<List<Relay>> checkDefaultRelay(List<Relay> relays) async {
    for (final r in relays) {
      if (r.isDefault) {
        return relays;
      }
    }
    final defaultRelay = relays.firstWhereOrNull(
      (element) => element.url == KeychatGlobal.defaultRelay,
    );
    if (defaultRelay == null) {
      final relay = await add(KeychatGlobal.defaultRelay);
      relays.add(relay);
      return relays;
    }
    defaultRelay.isDefault = true;
    await update(defaultRelay);
    relays
      ..removeWhere((element) => element.url == defaultRelay.url)
      ..add(defaultRelay);
    return relays;
  }

  Future<Map<String, dynamic>?> fetchRelayNostrInfo(Relay relay) async {
    final dio = Dio();
    try {
      late String url;
      if (relay.url.startsWith('ws://')) {
        url = relay.url.replaceFirst('ws://', 'http://');
      }
      if (relay.url.startsWith('wss://')) {
        url = relay.url.replaceFirst('wss://', 'https://');
      }
      if (url.isEmpty) return null;

      final res = await dio.get(
        url,
        options: Options(
          headers: {'Accept': 'application/nostr+json'},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      return res.data as Map<String, dynamic>?;
    } on DioException catch (e, s) {
      final msg = e.response?.data as String?;
      logger.e('relay faild: ${relay.url} , $msg', stackTrace: s);
    } catch (e, s) {
      logger.e('relay faild: ${relay.url} , $e', stackTrace: s);
    }
    return null;
  }

  Future<void> initRelayFeeInfo([List<Relay>? relays]) async {
    try {
      try {
        Get.find<WebsocketService>();
      } catch (e) {
        // skip if websocket not init
        return;
      }
      await RelayService.instance.fetchRelayMessageFee(relays);
      if (relays != null &&
          relays
              .map((item) => item.url)
              .contains(KeychatGlobal.defaultFileServer)) {
        await RelayService.instance.fetchRelayFileFee();
      }
    } catch (e, s) {
      logger.e('fee: $e', stackTrace: s);
    }
  }

  /// get a online relay and it is the default setting
  Future<String?> getDefaultOnlineRelay() async {
    final relay = await DBProvider.database.relays
        .filter()
        .isDefaultEqualTo(true)
        .findFirst();
    if (relay != null) return relay.url;

    final rw =
        Get.find<WebsocketService>().channels[KeychatGlobal.defaultRelay];
    if (rw != null) KeychatGlobal.defaultRelay;

    final relays = Get.find<WebsocketService>().channels.keys.toList();
    return relays.first;
  }

  Future<Relay?> getDefault() async {
    return DBProvider.database.relays
        .filter()
        .isDefaultEqualTo(true)
        .findFirst();
  }

  Future<List<Relay>> initRelay() async {
    final database = DBProvider.database;
    var list = await RelayService.instance.list();
    if (list.isEmpty) {
      await database.writeTxn(() async {
        final nostrRelays = Config.getEnvConfig('nostrRelays');
        if (nostrRelays is Iterable) {
          for (final url in nostrRelays) {
            final relay = Relay(url);
            await database.relays.put(relay);
          }
        }
      });
      list = await RelayService.instance.list();
    }
    // list = await checkDefaultRelay(list);
    return list;
  }

  Future<void> fetchRelayMessageFee([List<Relay>? relays]) async {
    final ws = Get.find<WebsocketService>();
    relays ??= await getEnableRelays();
    for (final relay in relays) {
      try {
        if (relay.errorMessage != null) {
          relay.errorMessage = null;
          update(relay);
        }

        final payInfo = await _fetchCashuPayInfo(relay);
        // logger.i('fetchRelayMessageFee, $relay: $payInfo');
        if (payInfo != null) {
          ws.relayMessageFeeModels[relay.url] = payInfo;
          ws.relayMessageFeeModels.refresh();
        }
      } catch (e, s) {
        logger.e(e.toString(), error: e, stackTrace: s);
      }
    }
    // store to local
    await Storage.setLocalStorageMap(
      StorageKeyString.relayMessageFeeConfig,
      ws.relayMessageFeeModels,
    );
  }

  Future<void> fetchRelayFileFee() async {
    final ws = Get.find<WebsocketService>();

    final fuc = await initRelayFileFeeModel(KeychatGlobal.defaultFileServer);
    if (fuc != null) {
      ws.setRelayFileFeeModel(KeychatGlobal.defaultFileServer, fuc);
    }

    // store to local
    await Storage.setLocalStorageMap(
      StorageKeyString.relayFileFeeConfig,
      ws.relayFileFeeModels,
    );
  }

  // curl -H "Accept: application/nostr+json" https://relay.keychat.io
  Future<RelayMessageFee?> _fetchCashuPayInfo(Relay relay) async {
    final Map? data = await fetchRelayNostrInfo(relay);
    if (data == null || data.isEmpty) return null;
    if (data['limitation'] != null) {
      final payRequired =
          data['limitation']['payment_required'] as bool? ?? false;
      if (payRequired) {
        final fees = data['fees'] as Map<String, dynamic>? ?? {};
        for (final map in fees.entries) {
          if (map.key == 'publication') {
            if (map.value.length == 0) continue;
            final publication = fees['publication'][0] as Map<String, dynamic>;
            if (publication['method'] != null) {
              final mints = <String>[];
              final mintsList =
                  publication['method']['Cashu']['mints'] as List?;
              if (mintsList != null) {
                for (final item in mintsList) {
                  mints.add(item as String);
                }
              }

              final payInfo = RelayMessageFee()
                ..amount = publication['amount'] as int? ?? 0
                ..unit = RelayMessageFee.getSymbolByName(
                  publication['unit'] as String? ?? '-',
                )
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
    final dio = Dio()
      ..options = BaseOptions(
        headers: {'Content-Type': 'application/json'},
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
        sendTimeout: const Duration(seconds: 6),
      );
    try {
      final response = await dio.get('$url/api/v1/info');

      if (response.statusCode == 200 && response.data is Map) {
        return response.data as Map<dynamic, dynamic>?;
      } else {
        loggerNoLine.e(
          'Failed to fetch file server info. Error: ${response.statusCode}',
        );
      }
    } catch (e) {
      loggerNoLine.e('Failed to fetch file server info', error: e);
    }

    return null;
  }

  Future<RelayFileFee?> initRelayFileFeeModel(String url) async {
    try {
      final map = await _fetchFileUploadConfig(url);
      logger.i('fetchAndSetFileUploadConfig, $url: $map');
      if (map != null) {
        final rufc = RelayFileFee()
          ..maxSize = map['maxsize'] as int? ?? 0
          ..mints = map['mints'] as List<dynamic>? ?? []
          ..prices = map['prices'] as List<dynamic>? ?? []
          ..unit = map['unit'] as String? ?? '-'
          ..expired = map['expired'] as String? ?? '-';
        return rufc;
      }
    } catch (e) {
      loggerNoLine.e(e.toString());
    }
    return null;
  }

  Future<int> addOrActiveRelay(List<String> relays) async {
    var success = 0;
    for (final url in relays) {
      final result = await addAndConnect(url);
      if (result) {
        success++;
      }
    }
    return success;
  }
}

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:isar_community/isar.dart';
import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/global.dart';
import 'package:keychat/models/embedded/relay_file_fee.dart';
import 'package:keychat/models/embedded/relay_message_fee.dart';
import 'package:keychat/models/models.dart';
import 'package:keychat/service/identity.service.dart';
import 'package:keychat/service/mls_group.service.dart';
import 'package:keychat/service/notify.service.dart';
import 'package:keychat/service/storage.dart';
import 'package:keychat/service/websocket.service.dart';
import 'package:keychat/utils.dart';
import 'package:keychat/utils/config.dart';

class RelayService {
  // Avoid self instance
  RelayService._();
  static final DBProvider dbProvider = DBProvider.instance;
  static final IdentityService identityService = IdentityService.instance;

  static RelayService? _instance;
  static RelayService get instance => _instance ??= RelayService._();

  /// Adds a relay by [url] to the pool and establishes a WebSocket connection.
  ///
  /// If already connected, returns false without reconnecting.
  /// On successful connection, triggers MLS key package upload and fee info fetch.
  Future<bool> addAndConnect(String url) async {
    final ws = Get.find<WebsocketService>();
    final relay = await RelayService.instance.getOrPutRelay(url);

    if (ws.channels[url] != null) {
      if (ws.channels[url]!.isConnected()) return false; // already connected
      ws.channels.remove(url);
    }
    relay
      ..active = true
      ..errorMessage = null;
    await update(relay);
    await ws.addChannel(
      relay,
      connectedCallback: () async {
        unawaited(NotifyService.instance.syncPubkeysToServer());
        unawaited(RelayService.instance.refreshRelayInfo(relays: [relay]));
        final identities = Get.find<HomeController>().allIdentities.values
            .toList();
        await MlsGroupService.instance.uploadKeyPackages(
          toRelay: relay.url,
          identities: identities,
        );
      },
    );
    return true;
  }

  /// Persists a new [Relay] record for [url] to the database.
  ///
  /// Set [isDefault] to true to mark this relay as the primary relay.
  /// Does not establish a WebSocket connection — use [addAndConnect] instead.
  Future<Relay> add(String url, [bool isDefault = false]) async {
    final database = DBProvider.database;
    final relay = Relay(url);
    await database.writeTxn(() async {
      relay.isDefault = isDefault;
      await database.relays.put(relay);
    });
    return relay;
  }

  /// Returns the existing [Relay] for [url], or creates and persists a new one if not found.
  ///
  /// Throws if the relay cannot be read back after insertion.
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

  // DEPRECATED: read/write relay split was removed in favor of a single active flag - candidate for removal
  // Future<List<Relay>> getReadList() async { ... }
  // Future<List<Relay>> getWriteList() async { ... }

  /// Deletes the relay record with the given [id] from the database.
  ///
  /// Returns true if the record was found and deleted.
  Future<bool> delete(int id) async {
    final database = DBProvider.database;

    return database.writeTxn(() async {
      return database.relays.delete(id);
    });
  }

  /// Returns all relay records, deduplicated by URL.
  Future<List<Relay>> list() async {
    final list = await DBProvider.database.relays.where().findAll();

    final newList = <String, Relay>{};
    for (final relay in list) {
      newList[relay.url] = relay;
    }
    return newList.values.toList();
  }

  /// Returns the URLs of all active (enabled) relays.
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

  /// Returns all active (enabled) [Relay] objects.
  Future<List<Relay>> getEnableRelays() async {
    final list = await DBProvider.database.relays
        .filter()
        .activeEqualTo(true)
        .findAll();

    return list;
  }

  /// Returns the total number of relay records in the database.
  Future<int> count() async {
    return DBProvider.database.relays.where().count();
  }

  /// Updates the read/write flags and active status for the relay with [id].
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
        relay
          ..read = read
          ..write = write
          ..active = active
          ..errorMessage = null;

        await database.relays.put(relay);
      }
    });
  }

  /// Updates [relay]'s error message and optional timestamp in the database.
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

  /// Toggles NIP-104 (MLS key packages) support for the relay at [relayUrl].
  ///
  /// Updates both the database and the in-memory [RelayWebsocket] relay object.
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

  /// Persists changes to an existing [Relay] record in the database.
  Future<void> update(Relay relay) async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.relays.put(relay);
    });
  }

  /// Sets or clears the default flag for [relay].
  ///
  /// If [afterValue] is true, first clears [isDefault] on all existing default relays,
  /// then marks [relay] as the new default.
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

  /// Ensures at least one relay in [relays] is marked as default.
  ///
  /// If none is set, uses [KeychatGlobal.defaultRelay], adding it if necessary.
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

  /// Fetches the NIP-11 relay information document from [relay] via HTTPS.
  ///
  /// Converts `wss://` to `https://` and sends a request with `Accept: application/nostr+json`.
  /// Returns the parsed JSON map, or null if the request fails.
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
      logger.i('fetchRelayNostrInfo, $url: ${res.data}');
      return res.data as Map<String, dynamic>?;
    } on DioException catch (e, s) {
      final msg = e.response?.data as String?;
      logger.e('relay faild: ${relay.url} , $msg', stackTrace: s);
    } catch (e, s) {
      logger.e('relay faild: ${relay.url} , $e', stackTrace: s);
    }
    return null;
  }

  /// Fetches NIP-11 relay info for [relays], caches supported_nips and fee config.
  ///
  /// Returns a map of relay URL → NIP-11 JSON data (null if fetch failed).
  /// Skips silently if [WebsocketService] is not yet initialized.
  /// Throttled to at most once per day; pass [force] = true to bypass.
  Future<Map<String, Map<String, dynamic>?>> refreshRelayInfo({
    List<Relay>? relays,
    bool force = false,
  }) async {
    final result = <String, Map<String, dynamic>?>{};
    try {
      final WebsocketService ws;
      try {
        ws = Get.find<WebsocketService>();
      } catch (e) {
        return result;
      }

      // Throttle: at most once per day
      if (!force) {
        final lastFetch =
            Storage.getInt(StorageKeyString.lastRelayInfoFetchTime);
        if (lastFetch != null) {
          final elapsed = DateTime.now().millisecondsSinceEpoch - lastFetch;
          if (elapsed < const Duration(days: 1).inMilliseconds) {
            return result;
          }
        }
      }

      relays ??= await getEnableRelays();
      for (final relay in relays) {
        try {
          if (relay.errorMessage != null) {
            relay.errorMessage = null;
            update(relay);
          }

          final data = await fetchRelayNostrInfo(relay);
          result[relay.url] = data;
          _cacheRelaySupportedNips(ws, relay.url, data);
          final payInfo = _parseCashuPayInfo(data);
          if (payInfo != null) {
            ws.relayMessageFeeModels[relay.url] = payInfo;
            ws.relayMessageFeeModels.refresh();
          }
        } catch (e, s) {
          logger.e(e.toString(), error: e, stackTrace: s);
        }
      }

      await Storage.setLocalStorageMap(
        StorageKeyString.relayMessageFeeConfig,
        ws.relayMessageFeeModels,
      );

      if (relays
          .map((item) => item.url)
          .contains(KeychatGlobal.defaultFileServer)) {
        await fetchRelayFileFee();
      }

      await Storage.setInt(
        StorageKeyString.lastRelayInfoFetchTime,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e, s) {
      logger.e('refreshRelayInfo: $e', stackTrace: s);
    }
    return result;
  }

  /// Returns the relay currently marked as default, or null if none is set.
  Future<Relay?> getDefault() async {
    return DBProvider.database.relays
        .filter()
        .isDefaultEqualTo(true)
        .findFirst();
  }

  /// Initializes the relay list from the database, seeding defaults from config if empty.
  ///
  /// On first run, populates relays from the `nostrRelays` environment config.
  Future<List<Relay>> initRelay() async {
    final database = DBProvider.database;
    var list = await RelayService.instance.list();
    if (list.isEmpty) {
      await database.writeTxn(() async {
        final nostrRelays = Config.getEnvConfig('nostrRelays');
        if (nostrRelays is Iterable) {
          for (final url in nostrRelays) {
            final relay = Relay(url as String);
            await database.relays.put(relay);
          }
        }
      });
      list = await RelayService.instance.list();
    }
    // list = await checkDefaultRelay(list);
    return list;
  }

  /// Fetches file upload fee configuration from the default file server and caches it locally.
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

  /// Caches supported_nips from NIP-11 relay info onto the RelayWebsocket.
  void _cacheRelaySupportedNips(
    WebsocketService ws,
    String relayUrl,
    Map<String, dynamic>? data,
  ) {
    final rw = ws.channels[relayUrl];
    if (rw == null || data == null) return;
    final nips = data['supported_nips'] as List<dynamic>?;
    if (nips != null) {
      rw.supportedNips = nips.whereType<int>().toSet();
    }
  }

  // curl -H "Accept: application/nostr+json" https://relay.keychat.io
  RelayMessageFee? _parseCashuPayInfo(Map<String, dynamic>? data) {
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

  /// Fetches and parses the file server info JSON from [url] into a [RelayFileFee] model.
  ///
  /// Returns null if the fetch fails or the server returns no useful data.
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

  /// Connects to each URL in [relays] that is not already active.
  ///
  /// Returns the count of relays successfully added or reconnected.
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

  /// Returns the [Relay] record matching [url], or null if not found.
  Future<Relay?> getRelayByUrl(String url) async {
    return DBProvider.database.relays.filter().urlEqualTo(url).findFirst();
  }
}

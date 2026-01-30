import 'dart:async' show Completer, FutureOr, Timer, unawaited;
import 'dart:convert' show jsonDecode;
import 'dart:io' show File;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat/rust_api.dart';
import 'package:keychat/service/relay.service.dart';
import 'package:keychat/service/secure_storage.dart';
import 'package:keychat/service/websocket.service.dart';
import 'package:keychat_ecash/Bills/lightning_utils.dart.dart';
import 'package:keychat_ecash/NostrWalletConnect/NostrWalletConnect_controller.dart';
import 'package:keychat_ecash/PayInvoice/PayInvoice_page.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';

class EcashDBVersion {
  static const int v0 = 0; // not initial version
  static const int v1 = 1; // initial version
  static const int v2 = 2;
}

class EcashController extends GetxController {
  EcashController(this.dbPath);
  final String dbPath;
  RxBool cashuInitFailed = false.obs;
  RxBool isBalanceLoading = true.obs; // Keep this
  RxBool isInitialized = false.obs; // Whether _initCashuMints has completed

  RxList<MintBalanceClass> mintBalances = <MintBalanceClass>[].obs;
  RxInt btcPrice = 0.obs;
  RxInt totalSats = 0.obs;
  RxInt pendingCount = 0.obs;
  RxList<MintCashu> mints = <MintCashu>[].obs;

  Identity? currentIdentity;
  late ScrollController scrollController;
  // late TextEditingController nameController;

  @override
  Future<void> onInit() async {
    scrollController = ScrollController();
    // nameController = TextEditingController();

    super.onInit();
    Get.lazyPut(NostrWalletConnectController.new, fenix: true);
  }

  /// Wait for initialization to complete, with a maximum timeout of 10 seconds
  /// Returns true if initialized, false if timeout
  Future<bool> waitForInit() async {
    if (isInitialized.value) {
      return true;
    }

    final completer = Completer<bool>();
    late Worker worker;
    Timer? timeoutTimer;

    worker = ever(isInitialized, (bool value) {
      if (value && !completer.isCompleted) {
        timeoutTimer?.cancel();
        worker.dispose();
        completer.complete(true);
      }
    });

    timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (!completer.isCompleted) {
        worker.dispose();
        completer.complete(false);
      }
    });

    return completer.future;
  }

  Future<String?> getFileUploadEcashToken(int fileSize) async {
    if (fileSize == 0) return null;
    final ws = Get.find<WebsocketService>();

    if (ws.relayFileFeeModels.isEmpty) {
      await RelayService.instance.fetchRelayFileFee();
      if (ws.relayFileFeeModels.isEmpty) return null;
    }

    String? mint;
    final fuc = ws.getRelayFileFeeModel(KeychatGlobal.defaultFileServer);
    if (fuc == null || fuc.mints.isEmpty) {
      throw Exception('FileServerNotAvailable');
    }

    mint = fuc.mints[0] as String? ?? KeychatGlobal.defaultCashuMintURL;
    if (!mint.endsWith('/')) {
      mint = '$mint/';
    }

    var unitPrice = 0;
    for (final price in fuc.prices) {
      if (fileSize >= (price['min'] as int) &&
          fileSize <= (price['max'] as int)) {
        unitPrice = price['price'] as int? ?? 0;
        break;
      }
    }
    if (unitPrice == 0) return null;

    final tx = await EcashUtils.getCashuToken(amount: unitPrice, mints: [mint]);
    return tx.token;
  }

  Future<void> _initCashuMints() async {
    const maxAttempts = 3;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        mints.value = [];
        final res = await rust_cashu.initCashu(
          prepareSatsOnceTime: KeychatGlobal.cashuPrepareAmount,
        );
        mints.addAll(res);
        logger.i('initCashu success ${mints.length} mints loaded');
        cashuInitFailed.value = false;
        cashuInitFailed.refresh();
        break;
      } catch (e, s) {
        logger.d(e.toString(), error: e, stackTrace: s);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (attempt == maxAttempts - 1) {
          cashuInitFailed.value = true;
          cashuInitFailed.refresh();
        }
      }
    }
    if (mints.isEmpty) {
      await initMintUrl();
    }
    unawaited(requestPageRefresh());
  }

  // move cashu token to v2
  Future<bool> upgradeToV2() async {
    final ecashDBVersion =
        Storage.getIntOrZero(StorageKeyString.ecashDBVersion);
    if (ecashDBVersion == EcashDBVersion.v2) return false;

    final dbV1Path = '$dbPath${KeychatGlobal.ecashDBFileV1}';
    final dbV2Path = '$dbPath${KeychatGlobal.ecashDBFileV2}';
    // new device
    if (ecashDBVersion == EcashDBVersion.v0) {
      final dbV1File = File(dbV1Path);
      if (!dbV1File.existsSync()) {
        logger.i('No v1 database found at $dbV1Path, skipping upgrade');
        await Storage.setInt(
          StorageKeyString.ecashDBVersion,
          EcashDBVersion.v2,
        );
        return false;
      }
    }
    // ecashDBVersion == EcashDBVersion.v1
    logger.i('Starting upgradeToV2 process');
    final words = await SecureStorage.instance.getOrCreatePhraseWords();
    try {
      await rust_cashu.initV1AndGetPoorfsToV2(
        dbpathOld: dbV1Path,
        dbpathNew: dbV2Path,
        words: words,
      );
      await Storage.setInt(
        StorageKeyString.ecashDBVersion,
        EcashDBVersion.v2,
      );
    } catch (e, s) {
      final msg = Utils.getErrorMessage(e);
      await EasyLoading.showError('initV1AndGetPoorfsToV2: $msg');
      logger.e('initV1AndGetPoorfsToV2: $msg', stackTrace: s);
      return false;
    }

    await rust_cashu.initDb(dbpath: dbV2Path, dev: kDebugMode, words: words);
    await rust_cashu.initCashu(
      prepareSatsOnceTime: KeychatGlobal.cashuPrepareAmount,
    );

    return true;
  }

  Future<void> initIdentity(Identity identity) async {
    currentIdentity = identity;

    final upgradeSuccess = await upgradeToV2();
    if (!upgradeSuccess) {
      final words = await SecureStorage.instance.getOrCreatePhraseWords();
      await rust_cashu.initDb(
        dbpath: '$dbPath${KeychatGlobal.ecashDBFileV2}',
        dev: kDebugMode,
        words: words,
      );
    }
    await _initCashuMints();
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }

  Future<void> getPendingCount() async {
    pendingCount.value =
        (await rust_cashu.getPendingTransactionsCount()).toInt();
  }

  Future<Map<String, int>> getBalance() async {
    isBalanceLoading.value = true;
    try {
      final res = await rust_cashu.getBalances();
      final resMap = jsonDecode(res) as Map<String, dynamic>;
      if (resMap.keys.isEmpty) {
        isBalanceLoading.value = false;
        return {};
      }
      final result = <String, int>{};
      // {https://8333.space:3338/: 0, https://mint.minibits.cash/Bitcoin/: 5}
      logger.i('cashu balance: $resMap');
      var total = 0;
      final localMints = <MintBalanceClass>[];
      for (final item in resMap.keys) {
        localMints.add(
          MintBalanceClass(
            item,
            EcashTokenSymbol.sat.name,
            resMap[item] as int,
          ),
        );
        total += resMap[item] as int;
      }
      totalSats.value = total;
      totalSats.refresh();
      localMints.sort((a, b) => b.balance - a.balance);
      mintBalances.value = localMints.toList();
      return result;
    } finally {
      isBalanceLoading.value = false;
    }
  }

  int getBalanceByMint(String mint, [String token = 'sat']) {
    for (final item in mintBalances) {
      if (item.mint == mint && item.token == token) {
        return item.balance;
      }
    }
    return 0;
  }

  bool existMint(String mint, String token) {
    for (final item in mintBalances) {
      if (item.mint == mint && item.token == token) {
        return true;
      }
    }
    return false;
  }

  List<String> getMintsString() {
    final res = <String>[];
    for (final item in mintBalances) {
      res.add(item.mint);
    }
    return res;
  }

  int getTotalByMints([
    List<String> mintsString = const [],
    String token = 'sat',
  ]) {
    if (mintsString.isEmpty) {
      mintsString = getMintsString();
    }
    if (mintsString.isEmpty) return 0;
    var total = 0;

    for (final item in mintBalances) {
      if (mintsString.contains(item.mint) && item.token == token) {
        total += item.balance;
      }
    }
    return total;
  }

  Map<String, int> getBalanceByMints(
    List<String> mints, [
    String token = 'sat',
  ]) {
    if (mints.isEmpty) return {};
    final res = <String, int>{};

    for (final item in mintBalances) {
      if (mints.contains(item.mint) && item.token == token) {
        res[item.mint] = item.balance;
      }
    }
    return res;
  }

  Future<void> fetchBitcoinPrice() async {
    final dio = Dio()
      ..options = BaseOptions(
        headers: {
          'Content-Type': 'application/json',
        },
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 5),
      );
    try {
      final response = await dio.get(
        'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd',
      );
      if (response.statusCode == 200) {
        final data = response.data;
        final price = data['bitcoin']['usd'];
        btcPrice.value = price as int? ?? 0;
      } else {
        logger.e('Failed to fetch BTC price. Error: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Failed to fetch BTC price', error: e);
    }
  }

  Future<void> initMintUrl() async {
    mints.value = await rust_cashu.getMints();
    if (mints.isEmpty) {
      await rust_cashu.addMint(url: KeychatGlobal.defaultCashuMintURL);
      mints.value = await rust_cashu.getMints();
      return;
    }
    await getBalance();
  }

  Future<void> addMintUrl(String mint) async {
    final uri = Uri.tryParse(mint);
    if (uri == null) {
      throw Exception('Invalid mint URL');
    }
    await rust_cashu.addMint(url: mint);
    mints.value = await rust_cashu.getMints();
    mints.refresh();
    await getBalance();
  }

  Future<void> restore() async {
    if (currentIdentity == null) return;
    final mnemonic = await currentIdentity!.getMnemonic();
    final errors = <String, dynamic>{};
    for (final m in mints) {
      final Map? nuts = m.info?.nuts;
      logger.d('restore mint ${m.url} nuts: $nuts');
      try {
        final res = await rust_cashu.restore(mintUrl: m.url, words: mnemonic);
        logger.d('restore mint ${res.$1.toInt()} proofs: ${res.$2.toInt()}');
      } catch (e) {
        errors[m.url] = e.toString();
        logger.e('Failed to restore mint ${m.url}: $e');
      }
    }
    if (errors.isNotEmpty) {
      final errorMsg = errors.entries
          .map((e) => 'Mint: ${e.key}, Error: ${e.value}')
          .join('\n');
      throw Exception('Restore errors:\n$errorMsg');
    }
    await getBalance();
  }

  bool supportMint(String mint) {
    for (final m in mints) {
      if (m.url == mint) {
        final Map? nuts = m.info?.nuts;
        if (nuts == null) return false;
      }
    }
    return true;
  }

  bool supportMelt(String mint) {
    for (final m in mints) {
      if (m.url == mint) {
        final Map? nuts = m.info?.nuts;
        if (nuts == null) return false;
      }
    }
    return true;
  }

  Future<void> requestPageRefresh() async {
    try {
      unawaited(rust_cashu.checkPending());
      await getBalance();
      isInitialized.value = true;
      // await getRecentTransactions();
      final pendings = await rust_cashu.getLnPendingTransactions();
      await LightningUtils.instance
          .checkPendings(pendings)
          .timeout(const Duration(minutes: 3));
    } catch (e) {
      logger.e('Failed to check and update pending transactions: $e');
    } finally {
      isInitialized.value = true;
    }
  }

  Future<void> proccessCashuString(
    String str, [
    void Function(String str)? callback,
  ]) async {
    try {
      final cashu = await RustAPI.decodeToken(encodedToken: str);
      await Get.dialog(CashuReceiveWidget(cashuinfo: cashu));
    } catch (e) {
      logger.e('Failed to process Cashu string: $e');
      if (callback == null) {
        throw Exception('Invalid Cashu Token');
      }
      return callback(str);
    }
  }

  /// Pay to lightning invoice or LNURL.
  /// Returns [CashuWalletTransaction] for Cashu payments or [NwcWalletTransaction] for NWC payments.
  /// [input] can be: lnbc invoice, lnurl, or lightning address (email format).
  FutureOr<WalletTransactionBase?> dialogToPayInvoice({
    String? input,
    bool isPay = false,
  }) async {
    if (input != null) {
      if (isEmail(input) || input.toUpperCase().startsWith('LNURL')) {
        return await Get.bottomSheet<WalletTransactionBase?>(
          ignoreSafeArea: false,
          isScrollControlled: GetPlatform.isMobile,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
          ),
          PayInvoicePage(invoce: input, isPay: isPay, showScanButton: false),
        );
      }
      try {
        await rust_cashu.decodeInvoice(encodedInvoice: input);
      } catch (e) {
        await EasyLoading.showError('Invalid lightning invoice');
        return null;
      }
    }
    return await Get.bottomSheet<WalletTransactionBase?>(
      clipBehavior: Clip.antiAlias,
      ignoreSafeArea: false,
      isScrollControlled: GetPlatform.isMobile,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      PayInvoicePage(
        invoce: input,
        isPay: isPay,
        showScanButton: !isPay,
      ),
    );
  }
}

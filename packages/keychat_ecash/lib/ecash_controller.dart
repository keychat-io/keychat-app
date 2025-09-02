import 'dart:async' show FutureOr;
import 'dart:convert' show jsonDecode;

import 'package:app/app.dart';
import 'package:app/models/embedded/relay_file_fee.dart';
import 'package:app/models/models.dart';
import 'package:app/rust_api.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/secure_storage.dart';
import 'package:app/service/websocket.service.dart';
import 'package:flutter/foundation.dart';
import 'package:keychat_ecash/Bills/ecash_bill_controller.dart';
import 'package:keychat_ecash/Bills/lightning_bill_controller.dart';
import 'package:keychat_ecash/PayInvoice/PayInvoice_page.dart';
import 'package:keychat_ecash/cashu_receive.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'NostrWalletConnect/NostrWalletConnect_controller.dart';

class EcashController extends GetxController {
  final String dbPath;
  EcashController(this.dbPath);
  RxBool cashuInitFailed = false.obs;

  RxList<MintBalanceClass> mintBalances = <MintBalanceClass>[].obs;
  RxInt btcPrice = 0.obs;
  RxInt totalSats = 0.obs;
  RxString latestMintUrl = KeychatGlobal.defaultCashuMintURL.obs;
  RxInt pendingCount = 0.obs;
  RxList<MintCashu> mints = <MintCashu>[].obs;

  Identity? currentIdentity;
  late ScrollController scrollController;
  late TextEditingController nameController;
  late RefreshController refreshController;
  late EcashBillController ecashBillController;
  late LightningBillController lightningBillController;
  @override
  void onInit() async {
    scrollController = ScrollController();
    nameController = TextEditingController();
    refreshController = RefreshController();
    ecashBillController = Get.put(EcashBillController());
    lightningBillController = Get.put(LightningBillController());
    super.onInit();
    Get.lazyPut(() => NostrWalletConnectController(), fenix: true);
  }

  Future<String?> getFileUploadEcashToken(int fileSize) async {
    if (fileSize == 0) return null;
    WebsocketService ws = Get.find<WebsocketService>();

    if (ws.relayFileFeeModels.isEmpty) {
      await RelayService.instance.fetchRelayFileFee();
      if (ws.relayFileFeeModels.isEmpty) return null;
    }

    String? mint;
    RelayFileFee? fuc =
        ws.getRelayFileFeeModel(KeychatGlobal.defaultFileServer);
    if (fuc == null || fuc.mints.isEmpty) {
      throw Exception('FileServerNotAvailable');
    }

    mint = fuc.mints[0] ?? KeychatGlobal.defaultCashuMintURL;
    if (!mint!.endsWith('/')) {
      mint = '$mint/';
    }

    int unitPrice = 0;
    for (var price in fuc.prices) {
      if (fileSize >= price['min'] && fileSize <= price['max']) {
        unitPrice = price['price'];
        break;
      }
    }
    if (unitPrice == 0) return null;

    CashuInfoModel cim =
        await CashuUtil.getCashuA(amount: unitPrice, mints: [mint]);

    return cim.token;
  }

  Future<void> _initCashu() async {
    const maxAttempts = 3;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        mints.value = [];
        var res = await rust_cashu.initCashu(
            prepareSatsOnceTime: KeychatGlobal.cashuPrepareAmount);
        logger.i('initCashu success');
        for (var item in res) {
          logger.d('${item.url} ${item.info?.nuts}');
        }
        mints.addAll(res);
        cashuInitFailed.value = false;
        cashuInitFailed.refresh();
        await upgradeToV2();
        break;
      } catch (e, s) {
        logger.d(e.toString(), error: e, stackTrace: s);
        await Future.delayed(const Duration(milliseconds: 100));
        if (attempt == maxAttempts - 1) {
          cashuInitFailed.value = true;
          cashuInitFailed.refresh();
        }
      }
    }
    if (mints.isEmpty) {
      await initMintUrl();
    }
  }

  // move cashu token to v2
  Future<void> upgradeToV2() async {
    logger.i('Starting upgradeToV2 process');
    bool upgradeToV2 =
        await Storage.getBool(StorageKeyString.upgradeToV2) ?? false;
    // if (upgradeToV2) return;
    List<String> tokens = [];
    logger
        .i('Upgrade not completed yet, starting token migration from v1 to v2');
    try {
      tokens = await rust_cashu.cashuV1InitSendAll(
          dbpath: '$dbPath${KeychatGlobal.ecashDBFile}',
          words:
              "medal sail elegant icon extra urban broom wrist tourist toast daughter frog");
      logger.i('Found ${tokens.length} tokens to migrate: $tokens');
    } catch (e, s) {
      String msg = Utils.getErrorMessage(e);
      EasyLoading.showError('Failed to fetch tokens: $msg');
      logger.e('Failed to fetch tokens from v1 database: $msg', stackTrace: s);
    }

    List<String> failedTokens = [];
    for (int i = 0; i < tokens.length; i++) {
      try {
        logger.d('Receiving token ${i + 1}/${tokens.length}');
        await rust_cashu.receiveToken(encodedToken: tokens[i]);
        logger.d('Successfully received token ${i + 1}/${tokens.length}');
      } catch (e, s) {
        String msg = Utils.getErrorMessage(e);
        logger.e('Failed to receive token ${tokens[i]}: $msg', stackTrace: s);
        failedTokens.add(tokens[i]);
      }
    }
    if (failedTokens.isEmpty) {
      logger.i('All tokens migrated successfully, marking upgrade as complete');
      await Storage.setBool(StorageKeyString.upgradeToV2, true);
      requestPageRefresh();
    } else {
      logger.w(
          'Some tokens failed to migrate, upgrade not marked as complete: $failedTokens');
    }
  }

  Future<void> initIdentity(Identity identity) async {
    currentIdentity = identity;

    try {
      final stopwatch = Stopwatch()..start();
      String words = await SecureStorage.instance.getOrCreatePhraseWords();
      await rust_cashu.initDb(
          dbpath: '$dbPath${KeychatGlobal.ecashDBFileV2}',
          dev: kDebugMode,
          words: words);

      stopwatch.stop();
      logger.i('ecash init completed in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e, s) {
      logger.e(e.toString(), error: e, stackTrace: s);
    }
    await _initCashu();
  }

  @override
  void onClose() {
    nameController.dispose();
    scrollController.dispose();
    refreshController.dispose();
    super.onClose();
  }

  Future getPendingCount() async {
    pendingCount.value =
        (await rust_cashu.getPendingTransactionsCount()).toInt();
  }

  Future<Map> getBalance() async {
    String res = await rust_cashu.getBalances();
    Map<String, dynamic> resMap = jsonDecode(res);
    if (resMap.keys.isEmpty) {
      return {};
    }
    Map<String, int> result = {};
    // {https://8333.space:3338/: 0, https://mint.minibits.cash/Bitcoin/: 5}
    logger.i('cashu balance: $resMap');
    int total = 0;
    List<MintBalanceClass> localMints = <MintBalanceClass>[];
    bool existLatestMint = false;
    int latestMintBalance = 0;
    for (String item in resMap.keys) {
      if (latestMintUrl.value == item) {
        latestMintBalance = resMap[item] as int;
        existLatestMint = true;
      }
      localMints
          .add(MintBalanceClass(item, EcashTokenSymbol.sat.name, resMap[item]));
      total += resMap[item] as int;
    }
    totalSats.value = total;
    totalSats.refresh();
    localMints.sort((a, b) => b.balance - a.balance);

    mintBalances.value = localMints.toList();

    // set latest mint url
    if (existLatestMint == false || latestMintBalance == 0) {
      for (var mb in localMints) {
        if (mb.balance > 0) {
          latestMintUrl.value = mb.mint;
          break;
        }
      }
    }
    return result;
  }

  int getBalanceByMint(String mint, [String token = 'sat']) {
    for (var item in mintBalances) {
      if (item.mint == mint && item.token == token) {
        return item.balance;
      }
    }
    return 0;
  }

  bool existMint(String mint, String token) {
    for (MintBalanceClass item in mintBalances) {
      if (item.mint == mint && item.token == token) {
        return true;
      }
    }
    return false;
  }

  List<String> getMintsString() {
    List<String> res = [];
    for (var item in mintBalances) {
      res.add(item.mint);
    }
    return res;
  }

  int getTotalByMints(
      [List<String> mintsString = const [], String token = 'sat']) {
    if (mintsString.isEmpty) {
      mintsString = getMintsString();
    }
    if (mintsString.isEmpty) return 0;
    int total = 0;

    for (var item in mintBalances) {
      if (mintsString.contains(item.mint) && item.token == token) {
        total += item.balance;
      }
    }
    return total;
  }

  Map getBalanceByMints(List<String> mints, [String token = 'sat']) {
    if (mints.isEmpty) return {};
    Map res = {};

    for (var item in mintBalances) {
      if (mints.contains(item.mint) && item.token == token) {
        res[item.mint] = item.balance;
      }
    }
    return res;
  }

  int getIndexByDefaultMint() {
    for (var i = 0; i < mintBalances.length; i++) {
      if (mintBalances[i].mint == latestMintUrl.value) {
        return i + 1;
      }
    }
    return 1;
  }

  Future fetchBitcoinPrice() async {
    final dio = Dio();
    dio.options = BaseOptions(
        headers: {
          'Content-Type': 'application/json',
        },
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 5));
    try {
      final response = await dio.get(
          'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd');
      if (response.statusCode == 200) {
        final data = response.data;
        final price = data['bitcoin']['usd'];
        btcPrice.value = price;
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
      latestMintUrl.value = KeychatGlobal.defaultCashuMintURL;
      mints.value = await rust_cashu.getMints();
      return;
    }
    // check latestMintUrl in mints
    bool existLastestMint = false;
    for (var item in mints) {
      if (item.url == latestMintUrl.value) {
        existLastestMint = true;
      }
    }
    if (!existLastestMint) {
      latestMintUrl.value = mints[0].url;
    }
    await getBalance();
  }

  Future addMintUrl(String mint) async {
    await rust_cashu.addMint(url: mint);
    await getBalance();
  }

  Future restore() async {
    if (currentIdentity == null) return;
    String? mnemonic = await currentIdentity!.getMnemonic();
    for (MintCashu m in mints) {
      Map? nuts = m.info?.nuts;
      if (nuts == null) continue;
      if (nuts['nut09'] != null) {
        await rust_cashu.restore(
          mintUrl: m.url,
          words: mnemonic,
        );
      }
    }
    await getBalance();
  }

  bool supportMint(String mint) {
    for (MintCashu m in mints) {
      if (m.url == mint) {
        Map? nuts = m.info?.nuts;
        if (nuts == null) return false;
      }
    }
    return true;
  }

  bool supportMelt(String mint) {
    for (MintCashu m in mints) {
      if (m.url == mint) {
        Map? nuts = m.info?.nuts;
        if (nuts == null) return false;
      }
    }
    return true;
  }

  Future requestPageRefresh() async {
    try {
      await rust_cashu.checkPending();
      await getBalance();
      await Utils.getGetxController<EcashBillController>()?.getTransactions();
      await Utils.getGetxController<LightningBillController>()
          ?.getTransactions();
      var pendings = await rust_cashu.getLnPendingTransactions();
      Utils.getGetxController<LightningBillController>()
          ?.checkPendings(pendings);
      // ignore: empty_catches
    } catch (e) {}
    refreshController.refreshCompleted();
  }

  Future proccessCashuAString(String str,
      [Function(String str)? callback]) async {
    try {
      CashuInfoModel cashu = await RustAPI.decodeToken(encodedToken: str);
      Get.dialog(CashuReceiveWidget(cashuinfo: cashu));
    } catch (e) {
      if (callback == null) {
        rethrow;
      }
      return callback(str);
    }
  }

  FutureOr<Transaction?> proccessPayLightningBill(String invoice,
      {bool isPay = false, Function? paidCallback}) async {
    try {
      await rust_cashu.decodeInvoice(encodedInvoice: invoice);
    } catch (e) {
      EasyLoading.showError('Invalid lightning invoice');
      return null;
    }
    return Get.bottomSheet<Transaction>(PayInvoicePage(
        invoce: invoice,
        isPay: isPay,
        showScanButton: !isPay,
        paidCallback: paidCallback));
  }
}

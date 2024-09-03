import 'dart:convert' show jsonDecode;

import 'package:app/controller/setting.controller.dart';
import 'package:app/models/embedded/relay_file_fee.dart';
import 'package:app/models/models.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:flutter/foundation.dart';
import 'package:keychat_ecash/Bills/ecash_bill_controller.dart';
import 'package:keychat_ecash/Bills/lightning_bill_controller.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:pull_to_refresh/pull_to_refresh.dart';

import 'package:app/global.dart';

import 'package:app/service/message.service.dart';
import 'package:app/utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EcashController extends GetxController {
  final String dbPath;
  EcashController(this.dbPath);
  RxBool cashuInitFailed = false.obs;

  RxList<MintBalanceClass> mintBalances = <MintBalanceClass>[].obs;
  RxInt btcPrice = 0.obs;
  RxInt totalSats = 0.obs;
  RxString latestMintUrl = KeychatGlobal.defaultCashuMintURL.obs;
  RxInt pendingCount = 0.obs;
  RxList<Mint> mints = <Mint>[].obs;

  Identity? currentIdentity;
  late ScrollController scrollController;
  late TextEditingController nameController;
  late RefreshController refreshController;

  @override
  void onInit() async {
    scrollController = ScrollController();
    nameController = TextEditingController();
    refreshController = RefreshController();
    super.onInit();
  }

  Future<String?> getFileUploadEcashToken(int fileSize) async {
    if (fileSize == 0) return null;
    WebsocketService ws = Get.find<WebsocketService>();
    SettingController settingController = Get.find<SettingController>();

    if (ws.relayFileFeeModels.isEmpty) {
      await RelayService().fetchRelayFileFee();
      if (ws.relayFileFeeModels.isEmpty) return null;
    }
    String? mint;
    RelayFileFee? fuc =
        ws.relayFileFeeModels[settingController.defaultFileServer.value];
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

  Future initWithoutIdentity() async {
    try {
      await rust_cashu.initDb(
          dbpath: '$dbPath${KeychatGlobal.ecashDBFile}', dev: kDebugMode);
      logger.i('rust api init success');
    } catch (e, s) {
      logger.e('init cashu error', error: e, stackTrace: s);
    }
    await _initCashu();
  }

  Future<void> _initCashu() async {
    await Future.delayed(const Duration(seconds: 1));
    // init ecash , try 3 times
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
        break;
      } catch (e, s) {
        logger.d(e.toString(), error: e, stackTrace: s);
        await Future.delayed(const Duration(seconds: 1));
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

  Future initIdentity(Identity identity) async {
    currentIdentity = identity;

    try {
      await rust_cashu.initDb(
          dbpath: '$dbPath${KeychatGlobal.ecashDBFile}',
          dev: kDebugMode,
          words: await identity.getMnemonic());
      logger.i('rust api init success');
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
    logger.i('cashu balance: $resMap');
    int total = 0;
    List<MintBalanceClass> localMints = <MintBalanceClass>[];
    bool existLastestMint = false;
    for (String item in resMap.keys) {
      if (latestMintUrl.value == item) {
        existLastestMint = true;
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
    if (existLastestMint == false) {
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

  Future updateMessageStatus() async {
    List txs = await rust_cashu.getPendingTransactions();
    List<Message> messages = await MessageService().getCashuPendingMessage();
    for (Message m in messages) {
      for (var i = 0; i < txs.length; i++) {
        CashuTransaction ct = txs[i].field0 as CashuTransaction;
        if (m.cashuInfo == null || m.cashuInfo?.id == null) {
          break;
        }

        if (ct.id == m.cashuInfo!.id) {
          if (m.cashuInfo!.status != ct.status) {
            m.cashuInfo!.status = ct.status;
            await MessageService().updateMessage(m);
            break;
          }
        }
      }
    }
  }

  Future initMintUrl() async {
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
    for (Mint m in mints) {
      Nuts? nuts = m.info?.nuts;
      if (nuts == null) continue;
      if (nuts.nut09.supported) {
        await rust_cashu.restore(
            mint: m.url,
            words: mnemonic,
            sleepmsAfterCheckABatch: BigInt.from(1000));
      }
    }
    await getBalance();
  }

  bool supportMint(String mint) {
    for (Mint m in mints) {
      if (m.url == mint) {
        Nuts? nuts = m.info?.nuts;
        if (nuts == null) return false;
        return !nuts.nut04.disabled;
      }
    }
    return true;
  }

  bool supportMelt(String mint) {
    for (Mint m in mints) {
      if (m.url == mint) {
        Nuts? nuts = m.info?.nuts;
        if (nuts == null) return false;
        return !nuts.nut05.disabled;
      }
    }
    return true;
  }

  Future requestPageRefresh() async {
    var lightningBillController = Get.find<LightningBillController>();
    await rust_cashu.checkPending();
    await getBalance();
    await Get.find<EcashBillController>().getTransactions();
    try {
      await lightningBillController.getTransactions();
      var pendings = await rust_cashu.getLnPendingTransactions();
      lightningBillController.checkPendings(pendings);
    } catch (e) {}
    refreshController.refreshCompleted();
  }
}

import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/global.dart';
import 'package:keychat/models/embedded/cashu_info.dart';
import 'package:keychat/rust_api.dart';
import 'package:keychat/service/message.service.dart';
import 'package:keychat/utils.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';

enum EcashTokenSymbol { sat, usdt }

class MintBalanceClass {
  MintBalanceClass(this.mint, this.token, this.balance);
  late String mint;
  late String token;
  late int balance;
}

class EcashUtils {
  static String errorSpent = 'Token already spent';
  static String errorInvalid = 'Invalid token';
  static String errorBlindedMessage = 'Blinded Message is already signed';
  static List<String> errorsUnique = [
    'UNIQUE constraint failed',
    'INSERT INTO promises',
  ];
  static List<String> errorsDuplicateKey = [
    'duplicate key value violates unique constraint',
    'INSERT INTO promises',
  ];

  static final Map<String, bool> _activeChecks = {};

  static Future<void> startCheckPending(
    Transaction tx,
    void Function(Transaction ct) callback,
  ) async {
    if (tx.status != TransactionStatus.pending) {
      callback(tx);
      return;
    }

    _activeChecks[tx.id] = true;

    while (_activeChecks[tx.id] != null && (_activeChecks[tx.id] ?? false)) {
      final ln = await rust_cashu.checkTransaction(id: tx.id);
      if (ln.status == TransactionStatus.success ||
          ln.status == TransactionStatus.failed) {
        callback(ln);
        unawaited(Get.find<EcashController>().requestPageRefresh());
        _activeChecks.remove(tx.id);
        return;
      }
      logger.d('Checking status: ${tx.id}');
      await Future<void>.delayed(const Duration(seconds: 3));
    }

    logger.d('Check stopped for transaction: ${tx.id}');
  }

  static void stopCheckPending(Transaction tx) {
    if (_activeChecks.containsKey(tx.id)) {
      _activeChecks.remove(tx.id);
      logger.d('Stopping check for transaction: ${tx.id}');
    }
  }

  static Future<CashuInfoModel?> handleReceiveToken({
    required String token,
    bool retry = false,
    int? messageId,
  }) async {
    final ec = Get.find<EcashController>();

    if (!retry) {
      EasyLoading.show(status: 'Redeeming...');
    }
    late rust_cashu.TokenInfo decoded;
    try {
      decoded = await rust_cashu.decodeToken(encodedToken: token);
    } catch (e, s) {
      EasyLoading.dismiss();
      EasyLoading.showError('Error: $e', duration: const Duration(seconds: 3));
      logger.e('receive error 2', error: e, stackTrace: s);
      return null;
    }
    if (!isValidEcashToken(decoded.unit.toString())) {
      EasyLoading.showError(
        'Error! Invalid token symbol.',
        duration: const Duration(seconds: 2),
      );
      return null;
    }

    final existMint = ec.existMint(decoded.mint, decoded.unit.toString());
    if (existMint) {
      return _processReceive(token: token, retry: retry, messageId: messageId);
    }
    await EasyLoading.dismiss();
    var isAddingMint = false;
    return Get.dialog<CashuInfoModel>(
      StatefulBuilder(
        builder: (context, setState) => CupertinoAlertDialog(
          title: const Text('Add Mint Server?'),
          content: Text(decoded.mint),
          actions: [
            CupertinoDialogAction(
              onPressed: isAddingMint ? null : () => Get.back<CashuInfoModel>(),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: isAddingMint
                  ? null
                  : () async {
                      setState(() {
                        isAddingMint = true;
                      });

                      try {
                        EasyLoading.show(status: 'Processing');
                        await ec.addMintUrl(decoded.mint);
                      } catch (e, s) {
                        final msg = Utils.getErrorMessage(e);
                        logger.e(msg, error: e, stackTrace: s);
                        EasyLoading.showError(
                          'Add Failed: $msg',
                          duration: const Duration(seconds: 3),
                        );
                        Get.back<CashuInfoModel>();
                        return;
                      }

                      final res = await _processReceive(
                        token: token,
                        retry: retry,
                        messageId: messageId,
                      );

                      Get.back<CashuInfoModel>(result: res);
                    },
              child: isAddingMint
                  ? const CupertinoActivityIndicator()
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  static bool isValidEcashToken(String unit) =>
      true; // unit == 'sat' || unit == 'usdt';

  static Future<CashuInfoModel?> _processReceive({
    required String token,
    bool retry = false,
    int? messageId,
  }) async {
    try {
      final model = await RustAPI.receiveToken(encodedToken: token);
      await Get.find<EcashController>().getBalance();
      if (messageId != null) {
        await MessageService.instance.updateMessageCashuStatus(messageId);
      }
      await EasyLoading.showToast(
        'Received ${model.amount} ${EcashTokenSymbol.sat.name}',
      );
      return model;
    } catch (e, s) {
      final msg = await ecashErrorHandle(e, s);
      if (msg.toLowerCase().contains(EcashUtils.errorSpent.toLowerCase())) {
        if (messageId != null) {
          await MessageService.instance.updateMessageCashuStatus(messageId);
        }
      }
    }
    return null;
  }

  static Future<void> dialogToRestore(String msg) {
    return Get.dialog<void>(
      CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(
          '''
Error: $msg
Please restore your ecash wallet from mint server to resolve this issue.
''',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: Get.back<void>,
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              if (Get.isDialogOpen ?? false) {
                Get.back<void>();
              }
              await EcashUtils.restoreFromMintServer();
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  static Future<String> ecashErrorHandle(Object e, StackTrace s) async {
    await EasyLoading.dismiss();
    final msg = Utils.getErrorMessage(e);
    final msgLower = msg.toLowerCase();
    logger.e(msg, error: e, stackTrace: s);
    if (msgLower.contains(
      EcashUtils.errorSpent.toLowerCase(),
    )) {
      await EasyLoading.showError(EcashUtils.errorSpent);
      await rust_cashu.checkProofs();
      return msg;
    }
    var shouldDialogToRestore = false;
    if (msgLower.contains(
      EcashUtils.errorBlindedMessage.toLowerCase(),
    )) {
      shouldDialogToRestore = true;
    }
    if (msgLower.contains(errorsUnique[0].toLowerCase()) ||
        msgLower.contains(errorsDuplicateKey[0].toLowerCase())) {
      if (msgLower.contains(errorsUnique[1].toLowerCase())) {
        shouldDialogToRestore = true;
      }
    }
    if (shouldDialogToRestore) {
      await dialogToRestore(msg);
      return msg;
    }
    await EasyLoading.showError(
      'Error: $msg',
      duration: const Duration(seconds: 3),
    );
    return msg;
  }

  static Future<CashuInfoModel> getCashuA({
    required int amount,
    required List<String> mints,
    String token = 'sat',
  }) async {
    var filledMint = KeychatGlobal.defaultCashuMintURL;
    final controller = Get.find<EcashController>();
    for (final mint in mints) {
      if (controller.getBalanceByMint(mint) >= amount) {
        filledMint = mint;
        break;
      }
    }
    final ct = await rust_cashu.send(
      amount: BigInt.from(amount),
      activeMint: filledMint,
    );
    return CashuInfoModel.fromRustModel(ct);
  }

  static Future<CashuInfoModel> getStamp({
    required int amount,
    required List<String> mints,
    String token = 'sat',
  }) async {
    // String filledMint = KeychatGlobal.defaultCashuMintURL;
    // EcashController controller = Get.find<EcashController>();
    // for (var mint in controller.getMintsString()) {
    //   if (controller.getBalanceByMint(mint) >= amount) {
    //     filledMint = mint;
    //     break;
    //   }
    // }
    final ct =
        await rust_cashu.sendStamp(amount: BigInt.from(amount), mints: mints);
    if (ct.isNeedSplit) {
      unawaited(
        rust_cashu
            .prepareOneProofs(mint: ct.tx.mintUrl)
            .catchError((dynamic e, st) {
          logger.e(e);
          return BigInt.from(-1);
        }),
      );
    }
    return CashuInfoModel.fromRustModel(ct.tx);
  }

  static Widget getStatusIcon(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.success:
        return const Icon(
          CupertinoIcons.check_mark_circled,
          color: Colors.green,
        );
      case TransactionStatus.failed:
      case TransactionStatus.expired:
        return const Icon(
          Icons.error,
          color: Colors.red,
        );
      case TransactionStatus.pending:
        return const Icon(
          CupertinoIcons.time,
          color: Colors.yellow,
        );
    }
  }

  static Widget getLNIcon(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.success:
        return const Icon(
          CupertinoIcons.check_mark_circled,
          color: Colors.green,
        );
      case TransactionStatus.failed:
        return const Icon(
          Icons.error,
          color: Colors.red,
        );
      case TransactionStatus.expired:
        return const Icon(
          Icons.error_sharp,
          color: Colors.grey,
        );
      case TransactionStatus.pending:
        return const Icon(
          CupertinoIcons.time,
          color: Colors.yellow,
        );
    }
  }

  static Widget getTransactionIcon(TransactionDirection direction) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: Get.isDarkMode ? Colors.white10 : Colors.grey.shade300,
      child: Icon(
        direction == TransactionDirection.outgoing
            ? CupertinoIcons.arrow_up
            : (direction == TransactionDirection.split
                ? CupertinoIcons.arrow_left_right
                : CupertinoIcons.arrow_down),
        color: Get.isDarkMode ? Colors.white : Colors.black,
        size: 20,
      ),
    );
  }

  static String getSymbolFromDirection(TransactionDirection direction) {
    switch (direction) {
      case TransactionDirection.outgoing:
        return '-';
      case TransactionDirection.incoming:
        return '+';
      case TransactionDirection.split:
        return '';
    }
  }

  static Future<void> restoreFromMintServer() async {
    try {
      await EasyLoading.show(
        status: '''
Please don't close or exit the app.
Restoring...''',
      );
      final ec = Get.find<EcashController>();
      if (ec.currentIdentity == null) {
        await EasyLoading.showError('No mnemonic');
        return;
      }
      await ec.restore();
      await EasyLoading.showToast('Successfully');
    } catch (e, s) {
      final msg = Utils.getErrorMessage(e);
      logger.e(e.toString(), error: e, stackTrace: s);
      await Get.dialog(
        CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text(msg),
          actions: [
            CupertinoDialogAction(
              onPressed: Get.back,
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}

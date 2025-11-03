import 'dart:async' show unawaited;

import 'package:app/global.dart';
import 'package:app/models/embedded/cashu_info.dart';
import 'package:app/rust_api.dart';
import 'package:app/service/message.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
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

class CashuUtil {
  static String errorSpent = 'Token already spent';
  static String errorInvalid = 'Invalid token';
  static String errorBlindedMessage = 'Blinded Message is already signed';

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
      Get.find<EcashController>().getBalance();
      if (messageId != null) {
        MessageService.instance.updateMessageCashuStatus(messageId);
      }
      EasyLoading.showToast(
        'Received ${model.amount} ${EcashTokenSymbol.sat.name}',
      );
      return model;
    } catch (e, s) {
      EasyLoading.dismiss();
      final message = Utils.getErrorMessage(e);
      logger.e('receive error: $message', error: e, stackTrace: s);

      if (message.toLowerCase().contains(CashuUtil.errorSpent.toLowerCase())) {
        EasyLoading.showError(CashuUtil.errorSpent);
        if (messageId != null) {
          await MessageService.instance.updateMessageCashuStatus(messageId);
        }
      } else if (message.contains(CashuUtil.errorBlindedMessage)) {
        await CashuUtil.blindedMessageErrorDialog(message);
      } else {
        EasyLoading.showError(
          'Error! $message',
          duration: const Duration(seconds: 3),
        );
      }
    }
    return null;
  }

  static Future<void> blindedMessageErrorDialog(String msg) {
    return Get.dialog<void>(
      CupertinoAlertDialog(
        title: const Text('Info'),
        content: Text(
          '''
$msg

Fix this: 
1. Go to Bitcoin Ecash -> Settings -> Restore from Mint Server
2. After restore, try to receive the token again.
''',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: Get.back<void>,
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
      // return TextButton(
      //     onPressed: () async {
      //       CashuInfoModel? cm = await Get.dialog(CashuReceiveWidget(
      //           cashuinfo: CashuInfoModel.fromRustModel(cashuTransaction)));
      //       if (cm != null) {
      //         await controller.getTransactions();
      //       }
      //     },
      //     child: const Text('Pending'));
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

  static String getCashuAmount(Transaction transaction) {
    switch (transaction.io) {
      case TransactionDirection.outgoing:
        return '-${transaction.amount}';
      case TransactionDirection.incoming:
        return '+${transaction.amount}';
      case TransactionDirection.split:
        return transaction.amount.toString();
    }
  }

  static String getLNAmount(Transaction transaction) {
    switch (transaction.io) {
      case TransactionDirection.outgoing:
        return '-${transaction.amount}';
      case TransactionDirection.incoming:
        return '+${transaction.amount}';
      case TransactionDirection.split:
        return transaction.amount.toString();
    }
  }
}

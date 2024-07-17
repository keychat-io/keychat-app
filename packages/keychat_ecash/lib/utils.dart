import 'package:app/global.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rustCashu;
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:app/models/embedded/cashu_info.dart';
import 'package:app/rust_api.dart';
import 'package:app/service/message.service.dart';
import 'package:app/utils.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';

enum EcashTokenSymbol { sat, usdt }

class MintBalanceClass {
  late String mint;
  late String token;
  late int balance;
  MintBalanceClass(this.mint, this.token, this.balance);
}

class CashuUtil {
  static Future<CashuInfoModel?> handleReceiveToken(
      {required String token, bool retry = false, int? messageId}) async {
    var ec = Get.find<EcashController>();

    if (!retry) {
      EasyLoading.show(status: 'Receiving...');
    }
    late rustCashu.TokenInfo decoded;
    try {
      decoded = await rustCashu.decodeToken(encodedToken: token);
    } catch (e, s) {
      EasyLoading.dismiss();
      EasyLoading.showError('Error: ${e.toString()}',
          duration: const Duration(seconds: 3));
      logger.e('receive error 2', error: e, stackTrace: s);
      return null;
    }
    if (!isValidEcashToken(decoded.unit ?? EcashTokenSymbol.sat.name)) {
      EasyLoading.showError('Error! Invalid token symbol.',
          duration: const Duration(seconds: 2));
      return null;
    }

    bool existMint =
        ec.existMint(decoded.mint, decoded.unit ?? EcashTokenSymbol.sat.name);
    if (existMint) {
      return await _processReceive(
          token: token, retry: retry, messageId: messageId);
    }
    EasyLoading.dismiss();
    return await Get.dialog(CupertinoAlertDialog(
      title: const Text('Add Mint Server?'),
      content: Text(''' ${decoded.mint}'''),
      actions: [
        CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () {
              Get.back(result: null);
            }),
        CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              try {
                EasyLoading.show(status: 'Processing');
                await ec.addMintUrl(decoded.mint);
                EasyLoading.showToast('Added');
              } catch (e, s) {
                EasyLoading.showError('Add Failed: ${e.toString()}',
                    duration: const Duration(seconds: 3));
                logger.e(e.toString(), error: e, stackTrace: s);
                Get.back(result: null);
                return;
              }

              var res = await _processReceive(
                  token: token, retry: retry, messageId: messageId);

              Get.back(result: res);
            },
            child: const Text('Add'))
      ],
    ));
  }

  static bool isValidEcashToken(String unit) => unit == 'sat' || unit == 'usdt';

  static _processReceive(
      {required String token, bool retry = false, int? messageId}) async {
    try {
      CashuInfoModel model = await RustAPI.receiveToken(encodedToken: token);
      Get.find<EcashController>().getBalance();
      if (messageId != null) {
        MessageService().updateMessageCashuStatus(messageId);
      }
      EasyLoading.showToast(
          'Received ${model.amount} ${EcashTokenSymbol.sat.name}');
      return model;
    } catch (e, s) {
      EasyLoading.dismiss();
      String message = Utils.getErrorMessage(e);
      if (message.contains('11001')) {
        EasyLoading.showError('Exception: Token already spent.');
        if (messageId != null) {
          await MessageService().updateMessageCashuStatus(messageId);
        }
      } else {
        EasyLoading.showError('Error! $message',
            duration: const Duration(seconds: 2));
      }
      logger.e('receive error: $message', error: e, stackTrace: s);
    }
    return null;
  }

  static Future<CashuInfoModel> getCashuA({
    required int amount,
    required List<String> mints,
    String token = 'sat',
  }) async {
    String filledMint = KeychatGlobal.defaultCashuMintURL;
    EcashController controller = Get.find<EcashController>();
    for (var mint in mints) {
      if (controller.getBalanceByMint(mint) >= amount) {
        filledMint = mint;
        break;
      }
    }
    var ct = await rustCashu.send(
        amount: BigInt.from(amount), activeMint: filledMint);
    return CashuInfoModel.fromRustModel(ct.field0 as CashuTransaction);
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
      default:
        return const SizedBox();
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
      default:
        return const SizedBox();
    }
  }
}

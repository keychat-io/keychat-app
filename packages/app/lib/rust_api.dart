// import 'dart:io' show Platform;
import 'package:app/global.dart';
import 'package:app/models/embedded/cashu_info.dart';
import 'package:app/utils.dart';

import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rustCashu;
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
// import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rustNostr;
// import 'package:keychat_rust_ffi_plugin/api_signal.dart' as rustSignal;

// const _base = 'rust';

// final _dylib = Platform.isMacOS
//     ? '$_base.dylib'
//     : Platform.isWindows
//         ? '$_base.dll'
//         : 'lib$_base.so';

class RustAPI {
  static Future initEcashDB(String path) async {
    try {
      path = '$path${KeychatGlobal.ecashDBFile}';
      await rustCashu.initDb(dbpath: path);
      logger.i('rust api init success');
    } catch (e, s) {
      logger.e(e.toString(), error: e, stackTrace: s);
    }
    await Future.delayed(const Duration(seconds: 1));
    // init ecash , try 3 times
    const maxAttempts = 3;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        await rustCashu.initCashu(
            prepareSatsOnceTime: KeychatGlobal.cashuPrepareAmount);
        break;
      } catch (e) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  // static Future<CashuTransaction> sendCashu(
  //     {required int amount, required String activeMint}) async {
  //   Transaction transaction =
  //       await rustCashu.send(amount: amount, activeMint: activeMint);
  //   CashuTransaction ct = transaction.field0 as CashuTransaction;
  //   return ct;
  // }

  static Future<CashuInfoModel> receiveToken(
      {required String encodedToken}) async {
    List<Transaction> transactions =
        await rustCashu.receiveToken(encodedToken: encodedToken);
    CashuTransaction ct = transactions[0].field0 as CashuTransaction;
    return CashuInfoModel()
      ..id = ct.id
      ..status = TransactionStatus.success
      ..amount = ct.amount.toInt()
      ..token = ct.token
      ..mint = ct.mint;
  }

  static Future<CashuInfoModel> decodeToken(
      {required String encodedToken}) async {
    var tokenData = await rustCashu.decodeToken(encodedToken: encodedToken);

    return CashuInfoModel()
      ..status = TransactionStatus.pending
      ..token = encodedToken
      ..amount = tokenData.amount.toInt()
      ..unit = tokenData.unit
      ..memo = tokenData.memo
      ..mint = tokenData.mint;
  }

  static void closeDB() {
    rustCashu.closeDb();
  }
}

import 'package:app/models/embedded/cashu_info.dart';

import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';

class RustAPI {
  static Future<CashuInfoModel> receiveToken(
      {required String encodedToken}) async {
    List<Transaction> transactions =
        await rust_cashu.receiveToken(encodedToken: encodedToken);
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
    var tokenData = await rust_cashu.decodeToken(encodedToken: encodedToken);

    return CashuInfoModel()
      ..status = TransactionStatus.pending
      ..token = encodedToken
      ..amount = tokenData.amount.toInt()
      ..unit = tokenData.unit
      ..memo = tokenData.memo
      ..mint = tokenData.mint;
  }

  static void closeDB() {
    rust_cashu.closeDb();
  }
}

import 'package:keychat/models/embedded/cashu_info.dart';

import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';

class RustAPI {
  static Future<CashuInfoModel> converTransactionToCIM({
    required Transaction ct,
  }) async {
    return CashuInfoModel()
      ..id = ct.id
      ..status = TransactionStatus.success
      ..amount = ct.amount.toInt()
      ..token = ct.token
      ..mint = ct.mintUrl;
  }

  static Future<CashuInfoModel> decodeToken({
    required String encodedToken,
  }) async {
    final tokenData = await rust_cashu.decodeToken(encodedToken: encodedToken);

    return CashuInfoModel()
      ..status = TransactionStatus.pending
      ..token = encodedToken
      ..amount = tokenData.amount.toInt()
      ..unit = tokenData.unit.toString()
      ..memo = tokenData.memo
      ..mint = tokenData.mint;
  }
}

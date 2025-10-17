import 'dart:async';

import 'package:app/utils.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';

class EcashUtil {
  // Avoid self instance
  EcashUtil._();
  static EcashUtil? _instance;
  static EcashUtil get instance => _instance ??= EcashUtil._();
  final Map<String, bool> _activeChecks = {};

  Future<void> startCheckPending(
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
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    logger.d('Check stopped for transaction: ${tx.id}');
  }

  void stopCheckPending(Transaction tx) {
    if (_activeChecks.containsKey(tx.id)) {
      _activeChecks.remove(tx.id);
      logger.d('Stopping check for transaction: ${tx.id}');
    }
  }
}

import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CashuStatus {
  static Widget getStatusIcon(TransactionStatus status, [double size = 30.0]) {
    switch (status) {
      case TransactionStatus.success:
        return Icon(CupertinoIcons.check_mark_circled,
            color: Colors.green, size: size);
      case TransactionStatus.failed:
      case TransactionStatus.expired:
        return Icon(Icons.error, color: Colors.red, size: size);
      case TransactionStatus.pending:
        return Icon(CupertinoIcons.time, color: Colors.yellow, size: size);
      default:
        return Icon(
          size: size,
          CupertinoIcons.time,
          color: Colors.yellow,
        );
    }
  }
}

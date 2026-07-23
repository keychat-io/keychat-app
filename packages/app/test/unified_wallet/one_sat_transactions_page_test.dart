import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/unified_wallet/models/wallet_base.dart';
import 'package:keychat_ecash/unified_wallet/pages/one_sat_transactions_page.dart';
import 'package:keychat_ecash/unified_wallet/unified_wallet_controller.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  testWidgets('refreshes 1sat transactions after returning from detail', (
    tester,
  ) async {
    final controller = _TestUnifiedWalletController();
    controller.oneSatTransactions.value = [
      _TestTransaction(status: WalletTransactionStatus.success),
    ];
    controller.hasMoreOneSatTransactions.value = false;

    Get.put<UnifiedWalletController>(controller);

    await tester.pumpWidget(
      const GetMaterialApp(
        home: OneSatTransactionsPage(),
      ),
    );

    await tester.tap(find.text('- 1'));
    await tester.pumpAndSettle();

    expect(find.text('Transaction Detail'), findsOneWidget);
    expect(controller.forceRefreshCount, 0);

    Get.back<void>();
    await tester.pumpAndSettle();

    expect(controller.forceRefreshCount, 1);
  });

  testWidgets('checks pending 1sat transactions while page remains open', (
    tester,
  ) async {
    final controller = _TestUnifiedWalletController();
    controller.oneSatTransactions.value = [_TestTransaction()];
    controller.refreshedTransactions = [
      _TestTransaction(status: WalletTransactionStatus.success),
    ];
    controller.hasMoreOneSatTransactions.value = false;

    Get.put<UnifiedWalletController>(controller);

    await tester.pumpWidget(
      const GetMaterialApp(
        home: OneSatTransactionsPage(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(controller.checkedTransactionIds, ['tx-1']);
    expect(controller.forceRefreshCount, 1);
    expect(
      controller.oneSatTransactions.single.status,
      WalletTransactionStatus.success,
    );
  });
}

class _TestUnifiedWalletController extends UnifiedWalletController {
  _TestUnifiedWalletController() {
    wallets.value = [_wallet];
    selectedIndex.value = 0;
  }

  int forceRefreshCount = 0;
  final checkedTransactionIds = <String>[];
  List<WalletTransactionBase> refreshedTransactions = const [];
  final _wallet = _TestWallet();

  @override
  // Avoid starting real wallet/provider work from the production controller.
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<void> loadOneSatTransactions({
    int limit = 20,
    WalletBase? wallet,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      forceRefreshCount++;
    }
    if (refreshedTransactions.isNotEmpty) {
      oneSatTransactions.value = refreshedTransactions;
    }
  }

  @override
  Future<WalletTransactionBase?> checkOneSatTransactionStatus(
    WalletTransactionBase transaction,
  ) async {
    checkedTransactionIds.add(transaction.id);
    return _TestTransaction(
      id: transaction.id,
      status: WalletTransactionStatus.success,
    );
  }
}

class _TestWallet extends WalletBase {
  @override
  String get id => 'https://8333.space:3338/';

  @override
  String get displayName => '8333.space';

  @override
  WalletProtocol get protocol => WalletProtocol.cashu;

  @override
  int get balanceSats => 1;

  @override
  bool get isBalanceLoading => false;

  @override
  IconData get icon => CupertinoIcons.bitcoin_circle;

  @override
  Color get primaryColor => Colors.orange;

  @override
  String get subtitle => id;

  @override
  bool get canSend => true;

  @override
  bool get canReceive => true;

  @override
  bool get supportsLightning => false;

  @override
  Object get rawData => id;

  @override
  Widget settingsPage() => const SizedBox.shrink();
}

class _TestTransaction extends WalletTransactionBase {
  _TestTransaction({
    this.id = 'tx-1',
    this.status = WalletTransactionStatus.pending,
  });

  @override
  final String id;

  @override
  String? get walletId => 'https://8333.space:3338/';

  @override
  int get amountSats => -1;

  @override
  DateTime get timestamp => DateTime(2026, 6, 21, 20, 55, 37);

  @override
  String? get description => null;

  @override
  final WalletTransactionStatus status;

  @override
  bool get isIncoming => false;

  @override
  WalletProtocol get protocol => WalletProtocol.cashu;

  @override
  Object get rawData => id;

  @override
  String? get preimage => null;

  @override
  String get paymentHash => id;

  @override
  int? get fee => 0;

  @override
  bool get isSuccess => false;

  @override
  String? get invoice => null;

  @override
  Future<void> navigateToTransactionDetail({String? walletId}) {
    return Get.to<void>(
          () => const Scaffold(
            body: Center(child: Text('Transaction Detail')),
          ),
        ) ??
        Future<void>.value();
  }
}

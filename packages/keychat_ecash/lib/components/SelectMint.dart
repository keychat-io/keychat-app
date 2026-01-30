import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/global.dart';
import 'package:keychat/page/theme.dart';
import 'package:keychat/utils.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_ecash/unified_wallet/unified_wallet_controller.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:keychat_ecash/wallet_selection_storage.dart';

class SelectMint extends StatelessWidget {
  SelectMint(this.mint, this.selectCallback, {super.key}) {
    selected.value = mint;
  }
  final String mint;
  final RxString selected = ''.obs;
  final void Function(String) selectCallback;
  final EcashController ecashController = Get.find<EcashController>();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.2,
      child: ListTile(
        title: Obx(
          () => Text(
            '${ecashController.getBalanceByMint(selected.value)} ${EcashTokenSymbol.sat.name}',
          ),
        ),
        subtitle: Obx(
          () => Text(
            selected.value.isEmpty
                ? 'Loading...'
                : Uri.parse(selected.value).host,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: IconButton(
          icon: Icon(
            CupertinoIcons.arrow_right_arrow_left,
            size: 16,
            color: MaterialTheme.lightScheme().primary,
          ),
          onPressed: selectMint,
        ),
        onTap: selectMint,
      ),
    );
  }

  Future<void> selectMint() async {
    if (ecashController.mintBalances.isEmpty) {
      EasyLoading.showError('No mint available');
      return;
    }

    final isRefreshing = false.obs;

    Future<void> handleRefresh() async {
      isRefreshing.value = true;
      try {
        await ecashController.getBalance();
      } finally {
        isRefreshing.value = false;
      }
    }

    final newSelectedMint = await Get.bottomSheet<String>(
      Container(
        decoration: BoxDecoration(
          color: Theme.of(Get.context!).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Wallet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(Get.context!).textTheme.titleLarge?.color,
                    ),
                  ),
                  Obx(() {
                    return IconButton(
                      icon: isRefreshing.value
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              CupertinoIcons.refresh,
                              color: MaterialTheme.lightScheme().primary,
                            ),
                      onPressed: isRefreshing.value ? null : handleRefresh,
                    );
                  }),
                ],
              ),
            ),
            Flexible(
              child: Obx(() {
                if (ecashController.mintBalances.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    child: const Center(
                      child: Text('No wallet available'),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: ecashController.mintBalances.length,
                  itemBuilder: (context, index) {
                    final mintBalance = ecashController.mintBalances[index];
                    final isSelected = mintBalance.mint == selected.value;

                    return ListTile(
                      leading: Icon(
                        CupertinoIcons.bitcoin_circle,
                        color: KeychatGlobal.bitcoinColor,
                      ),
                      title: Text(
                        Uri.parse(mintBalance.mint).host,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(mintBalance.mint),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${mintBalance.balance} sat',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              CupertinoIcons.check_mark_circled,
                              color: Colors.green,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                      onTap: () {
                        Get.back(result: mintBalance.mint);
                      },
                    );
                  },
                );
              }),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (newSelectedMint == null) return;
    selected.value = newSelectedMint;

    // save last used wallet
    final wb = Utils.getOrPutGetxController(create: UnifiedWalletController.new)
        .getWalletById(newSelectedMint);
    if (wb != null) {
      await WalletStorageSelection.saveWallet(wb);
    }
    selectCallback(newSelectedMint);
  }
}

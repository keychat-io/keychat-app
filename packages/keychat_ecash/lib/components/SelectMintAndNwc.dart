import 'package:keychat/app.dart';
import 'package:keychat/page/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat/utils.dart' show Utils;
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:keychat_ecash/unified_wallet/unified_wallet_controller.dart';

class SelectMintAndNwc extends StatefulWidget {
  const SelectMintAndNwc({super.key});

  @override
  State<SelectMintAndNwc> createState() => _SelectMintAndNwcState();
}

class _SelectMintAndNwcState extends State<SelectMintAndNwc> {
  late final EcashController ecashController;
  late final UnifiedWalletController unifiedWalletController;

  @override
  void initState() {
    super.initState();
    ecashController = Get.find<EcashController>();
    unifiedWalletController = Utils.getOrPutGetxController(
      create: UnifiedWalletController.new,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.2,
      child: ListTile(
        title: Obx(() {
          final selectedWallet = ecashController.selectedWallet.value;

          // Find the wallet from unifiedWalletController
          final wallet = unifiedWalletController.wallets.firstWhereOrNull(
            (w) => w.id == selectedWallet.id,
          );

          if (wallet == null || unifiedWalletController.isLoading.value) {
            return const Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          if (wallet.isBalanceLoading) {
            return const Text('Loading...');
          }

          return Text('${wallet.balanceSats} ${EcashTokenSymbol.sat.name}');
        }),
        subtitle: Obx(() {
          final selectedWallet = ecashController.selectedWallet.value;
          return Text(
            selectedWallet.displayName,
            overflow: TextOverflow.ellipsis,
          );
        }),
        trailing: IconButton(
          icon: Icon(
            CupertinoIcons.arrow_right_arrow_left,
            size: 16,
            color: MaterialTheme.lightScheme().primary,
          ),
          onPressed: selectWallet,
        ),
        onTap: selectWallet,
      ),
    );
  }

  Future<void> selectWallet() async {
    await Get.bottomSheet<void>(
      Container(
        decoration: BoxDecoration(
          color: Theme.of(Get.context!).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
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
                    final isRefreshing =
                        unifiedWalletController.isLoading.value;
                    return IconButton(
                      icon: isRefreshing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              CupertinoIcons.refresh,
                              color: MaterialTheme.lightScheme().primary,
                            ),
                      onPressed: isRefreshing
                          ? null
                          : () => unifiedWalletController.refreshAll(),
                    );
                  }),
                ],
              ),
            ),
            Flexible(
              child: Obx(() {
                final wallets = unifiedWalletController.wallets;

                if (unifiedWalletController.isLoading.value &&
                    wallets.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (wallets.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    child: const Center(
                      child: Text('No wallet available'),
                    ),
                  );
                }

                final currentSelectedWallet =
                    ecashController.selectedWallet.value;

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: wallets.length,
                  itemBuilder: (context, index) {
                    final wallet = wallets[index];
                    final isSelected = wallet.id == currentSelectedWallet.id;

                    return ListTile(
                      leading: Icon(
                        wallet.icon,
                        color: wallet.primaryColor,
                      ),
                      title: Text(
                        wallet.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        wallet.subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            wallet.isBalanceLoading
                                ? 'Loading...'
                                : '${wallet.balanceSats} sat',
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
                      onTap: () async {
                        // Update ecashController which is the source of truth
                        await ecashController.updateSelectedWallet(wallet);

                        // Also update unifiedWalletController to keep it in sync
                        final walletIndex = unifiedWalletController.wallets
                            .indexWhere((w) => w.id == wallet.id);
                        if (walletIndex != -1) {
                          unifiedWalletController.selectWallet(walletIndex);
                        }

                        Get.back<void>();
                      },
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

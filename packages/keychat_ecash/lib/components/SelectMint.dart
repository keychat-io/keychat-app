import 'package:keychat/page/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:settings_ui/settings_ui.dart';

class SelectMint extends StatelessWidget {
  SelectMint(this.mint, this.selectCallback, {super.key}) {
    selected.value = mint;
  }
  final String mint;
  final void Function(String) selectCallback;
  RxString selected = ''.obs;
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
            selected.value,
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

    final mint = await Get.bottomSheet<String>(
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
              child: Text(
                'Select Wallet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(Get.context!).textTheme.titleLarge?.color,
                ),
              ),
            ),
            Flexible(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Obx(() {
                    final sections = <SettingsSection>[
                      SettingsSection(
                        tiles: ecashController.mintBalances
                            .map(
                              (e) => SettingsTile(
                                title: Text(e.mint),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      e.balance.toString(),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    if (e.mint == selected.value) ...[
                                      const SizedBox(width: 8),
                                      const Icon(
                                        CupertinoIcons.check_mark,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                    ],
                                  ],
                                ),
                                onPressed: (context) {
                                  Get.back(result: e.mint);
                                },
                              ),
                            )
                            .toList(),
                      ),
                      SettingsSection(
                        tiles: [
                          SettingsTile(
                            title: Obx(
                              () => Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isRefreshing.value)
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else
                                    const Icon(
                                      CupertinoIcons.refresh,
                                      size: 16,
                                    ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isRefreshing.value
                                        ? 'Refreshing...'
                                        : 'Refresh Balances',
                                  ),
                                ],
                              ),
                            ),
                            onPressed: isRefreshing.value
                                ? null
                                : (context) => handleRefresh(),
                          ),
                        ],
                      ),
                    ];

                    return SettingsList(
                      platform: DevicePlatform.iOS,
                      sections: sections,
                    );
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (mint != null) {
      selected.value = mint;
      selectCallback(mint);
    }
  }
}

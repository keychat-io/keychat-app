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
    final mint = await Get.bottomSheet<String>(
      SettingsList(
        platform: DevicePlatform.iOS,
        sections: [
          SettingsSection(
            tiles: ecashController.mintBalances
                .map(
                  (e) => SettingsTile(
                    title: Text(e.mint),
                    value: Text(e.balance.toString()),
                    onPressed: (context) {
                      Get.back(result: e.mint);
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
    if (mint != null) {
      selected.value = mint;
      selectCallback(mint);
    }
  }
}

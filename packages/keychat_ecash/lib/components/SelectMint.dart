import 'package:app/page/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

class SelectMint extends StatefulWidget {
  final String mint;
  final Function selectCallback;
  const SelectMint(this.mint, this.selectCallback, {super.key});

  @override
  _SelectMintState createState() => _SelectMintState();
}

class _SelectMintState extends State<SelectMint> {
  String selected = '';
  late EcashController ecashController;

  @override
  void initState() {
    ecashController = Get.find<EcashController>();
    setState(() {
      selected = widget.mint;
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.2,
      child: ListTile(
        title: Text(
            '${ecashController.getBalanceByMint(selected).toString()} ${EcashTokenSymbol.sat.name}'),
        subtitle: Text(selected),
        trailing: IconButton(
            icon: Icon(
              CupertinoIcons.arrow_right_arrow_left,
              size: 16,
              color: MaterialTheme.lightScheme().primary,
            ),
            onPressed: selectMint),
        onTap: selectMint,
      ),
    );
  }

  void selectMint() async {
    if (ecashController.mintBalances.isEmpty) {
      EasyLoading.showError('No mint available');
      return;
    }
    String? mint = await Get.bottomSheet(SafeArea(
        child: SettingsList(platform: DevicePlatform.iOS, sections: [
      SettingsSection(
          tiles: ecashController.mintBalances
              .map((e) => SettingsTile(
                    title: Text(e.mint),
                    value: Text(e.balance.toString()),
                    onPressed: (context) {
                      Get.back(result: e.mint);
                    },
                  ))
              .toList())
    ])));
    if (mint != null) {
      setState(() {
        selected = mint;
        widget.selectCallback(mint);
      });
    }
  }
}

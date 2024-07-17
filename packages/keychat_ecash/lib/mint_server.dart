import 'package:app/page/theme.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class MintServerDart extends StatefulWidget {
  const MintServerDart({super.key});

  @override
  _MintServerDartState createState() => _MintServerDartState();
}

class _MintServerDartState extends State<MintServerDart> {
  @override
  Widget build(BuildContext context) {
    EcashController controller = Get.find<EcashController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        children: <Widget>[
          DrawerHeader(
              decoration: BoxDecoration(
                color: MaterialTheme.lightScheme().primary,
              ),
              child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(CupertinoIcons.bitcoin_circle,
                        color: Color(0xfff2a900), size: 80),
                    Text(
                      'Select Mint Server',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                  ])),
          Obx(() => ListView.builder(
              shrinkWrap: true,
              itemCount: controller.mintBalances.length,
              controller: controller.scrollController,
              itemBuilder: (context, index) {
                MintBalanceClass item = controller.mintBalances[index];
                return ListTile(
                    title: Text(item.mint),
                    trailing: Text(item.balance.toString()),
                    onTap: () {
                      controller.latestMintUrl.value = item.mint;
                      EasyLoading.showToast('Switch Mint Url Successfully');
                      Navigator.pop(context);
                    });
              }))
        ],
      ),
    );
  }
}

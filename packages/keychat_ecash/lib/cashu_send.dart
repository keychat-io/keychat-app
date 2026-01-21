import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat/utils.dart' show Utils;
import 'package:keychat_ecash/components/SelectMint.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_ecash/unified_wallet/unified_wallet_controller.dart';

class CashuSendPage extends StatefulWidget {
  const CashuSendPage({super.key});

  @override
  _CashuSendPageState createState() => _CashuSendPageState();
}

class _CashuSendPageState extends State<CashuSendPage> {
  late EcashController ecashController;
  late String selectedMint;
  final RxBool isLoading = false.obs;

  @override
  void initState() {
    ecashController = Get.find<EcashController>();
    ecashController.nameController.clear();
    ecashController.getBalance();
    selectedMint = ecashController.latestMintUrl.value;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
        child: Column(
          children: [
            AppBar(title: const Text('Pay Ecash(Cashu)')),
            Obx(
              () => SelectMint(ecashController.latestMintUrl.value,
                  (String mint) {
                setState(() {
                  selectedMint = mint;
                  ecashController.latestMintUrl.value = mint;
                });
              }),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: TextField(
                      style: const TextStyle(fontSize: 16),
                      controller: ecashController.nameController,
                      keyboardType: TextInputType.number,
                      // textInputAction: TextInputAction.done,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Amount',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.only(
                bottom: Get.isBottomSheetOpen ?? true
                    ? 0
                    : MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SizedBox(
                width: GetPlatform.isDesktop ? 200 : double.infinity,
                height: 44,
                child: Obx(
                  () => FilledButton(
                    onPressed: isLoading.value
                        ? null
                        : () async {
                            if (isLoading.value) return;

                            try {
                              isLoading.value = true;
                              if (GetPlatform.isMobile) {
                                HapticFeedback.lightImpact();
                              }
                              final amountString =
                                  ecashController.nameController.text.trim();
                              if (amountString.isEmpty) {
                                EasyLoading.showToast('Please input amount');
                                return;
                              }
                              var amount = 0;
                              try {
                                amount = int.parse(amountString);
                              } catch (e) {
                                EasyLoading.showToast('Invalid amount');
                                return;
                              }
                              if (amount == 0) {
                                EasyLoading.showToast('Amount should > 0');
                                return;
                              }
                              final balance = ecashController
                                  .getBalanceByMint(selectedMint);
                              if (balance < amount) {
                                EasyLoading.showToast('Insufficient balance');
                                return;
                              }
                              await EasyLoading.show(status: 'Generating...');
                              final tx = await EcashUtils.getCashuToken(
                                amount: amount,
                                mints: [selectedMint],
                              );

                              final unifiedController =
                                  Utils.getOrPutGetxController(
                                create: UnifiedWalletController.new,
                              );
                              await unifiedController.refreshSelectedWallet(
                                unifiedController.getWalletById(selectedMint),
                              );
                              await EasyLoading.showToast(
                                'Success',
                              );

                              Get.back(result: tx);
                            } catch (e, s) {
                              await EcashUtils.ecashErrorHandle(e, s);
                            } finally {
                              isLoading.value = false;
                            }
                          },
                    child: isLoading.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Send'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat/utils.dart' show Utils;
import 'package:keychat_ecash/components/SelectMint.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_ecash/unified_wallet/unified_wallet_controller.dart';
import 'package:keychat_ecash/wallet_selection_storage.dart';

class PayEcashPage extends StatefulWidget {
  const PayEcashPage({super.key});

  @override
  _PayEcashPageState createState() => _PayEcashPageState();
}

class _PayEcashPageState extends State<PayEcashPage> {
  late EcashController ecashController;
  String selectedMint = '';
  final RxBool isLoading = false.obs;
  late TextEditingController textEditingController;

  @override
  void initState() {
    ecashController = Get.find<EcashController>();
    textEditingController = TextEditingController();
    unawaited(init());
    super.initState();
  }

  Future<void> init() async {
    final mint = await WalletStorageSelection.getLasetMintWallet();
    setState(() {
      selectedMint = mint;
    });
  }

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
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
            SelectMint(selectedMint, (newMint) {
              selectedMint = newMint;
            }),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: TextField(
                style: const TextStyle(fontSize: 16),
                controller: textEditingController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Amount',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // if (kDebugMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  const Text(
                    'Quick select: ',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [1, 5, 10, 100, 1024].map((amount) {
                        return InkWell(
                          onTap: () {
                            textEditingController.text = amount.toString();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainer,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              amount.toString(),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
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
                                  textEditingController.text.trim();
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

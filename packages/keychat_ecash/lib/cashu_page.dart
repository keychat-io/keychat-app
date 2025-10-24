import 'dart:async';

import 'package:app/app.dart';
import 'package:app/page/components.dart';
import 'package:app/service/qrscan.service.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/Bills/cashu_transaction.dart';
import 'package:keychat_ecash/Bills/lightning_transaction.dart';
import 'package:keychat_ecash/Bills/transactions_page.dart';
import 'package:keychat_ecash/CreateInvoice/CreateInvoice_page.dart';
import 'package:keychat_ecash/EcashSetting/EcashSetting_bindings.dart';
import 'package:keychat_ecash/EcashSetting/MintServerPage.dart';
import 'package:keychat_ecash/PayInvoice/PayInvoice_page.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_ecash/receive_ecash_page.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:settings_ui/settings_ui.dart';

class CashuPage extends GetView<EcashController> {
  const CashuPage({super.key});

  Widget bottomBarWidget(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsGeometry.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Wrap(
              spacing: 16,
              runAlignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: GetPlatform.isMobile ? 120 : 200,
                  height: GetPlatform.isMobile ? 32 : 40,
                  child: FilledButton(
                    onPressed: _handleSend,
                    child: const Text('Send'),
                  ),
                ),
                IconButton(
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: () {
                    QrScanService.instance.handleQRScan();
                  },
                  icon: const Icon(CupertinoIcons.qrcode_viewfinder, size: 24),
                ),
                SizedBox(
                  width: GetPlatform.isMobile ? 120 : 200,
                  height: GetPlatform.isMobile ? 32 : 40,
                  child: FilledButton(
                    onPressed: _handleReceive,
                    child: const Text('Receive'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Bitcoin Ecash'),
        actions: [
          if (GetPlatform.isDesktop)
            IconButton(
              onPressed: () async {
                await controller.requestPageRefresh();
                await EasyLoading.showSuccess('Refreshed');
              },
              icon: const Icon(CupertinoIcons.refresh),
            ),
          IconButton(
            onPressed: () {
              Get.to(
                () => const EcashSettingPage(),
                binding: EcashSettingBindings(),
                id: GetPlatform.isDesktop ? GetXNestKey.ecash : null,
              );
            },
            icon: const Icon(CupertinoIcons.settings),
          ),
        ],
      ),
      bottomNavigationBar: bottomBarWidget(context),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          width: double.infinity,
          padding:
              GetPlatform.isDesktop ? const EdgeInsets.all(8) : EdgeInsets.zero,
          child: CustomMaterialIndicator(
            onRefresh: controller.requestPageRefresh,
            displacement: 20,
            backgroundColor: Colors.white,
            triggerMode: IndicatorTriggerMode.anywhere,
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Wrap(
                        direction: Axis.vertical,
                        children: [
                          const Text('Total Balance'),
                          Obx(
                            () => controller.isBalanceLoading.value
                                ? SizedBox(
                                    height: 60,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  )
                                : RichText(
                                    text: TextSpan(
                                      text:
                                          controller.totalSats.value.toString(),
                                      children: <TextSpan>[
                                        TextSpan(
                                          text: ' ${EcashTokenSymbol.sat.name}',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                      style: TextStyle(
                                        height: 1.3,
                                        fontSize: 48,
                                        color: Theme.of(context)
                                            .textTheme
                                            .titleLarge!
                                            .color,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Obx(
                  () => Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: CarouselSlider(
                      options: CarouselOptions(
                        height: 150,
                        disableCenter: true,
                        viewportFraction: 0.5,
                        padEnds: false,
                        enlargeCenterPage: true,
                        enableInfiniteScroll: false,
                      ),
                      items: [
                        ...controller.mintBalances,
                        '+',
                      ].map((element) {
                        if (element == '+') {
                          return Builder(
                            builder: (BuildContext context) {
                              return Container(
                                width: MediaQuery.of(context).size.width / 2,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withAlpha(10),
                                      Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withAlpha(40),
                                    ],
                                  ),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    CupertinoIcons.add_circled,
                                    size: 48,
                                  ),
                                  onPressed: () {
                                    final mintController =
                                        TextEditingController();
                                    Get.dialog(
                                      CupertinoAlertDialog(
                                        title: const Text('Add Mint'),
                                        content: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          child: TextField(
                                            decoration: const InputDecoration(
                                              hintText: 'Mint URL',
                                              border: OutlineInputBorder(),
                                            ),
                                            controller: mintController,
                                          ),
                                        ),
                                        actions: [
                                          CupertinoDialogAction(
                                            child: const Text('Cancel'),
                                            onPressed: () async {
                                              Get.back<void>();
                                            },
                                          ),
                                          CupertinoDialogAction(
                                            isDefaultAction: true,
                                            child: const Text('Add'),
                                            onPressed: () async {
                                              final input =
                                                  mintController.text.trim();
                                              if (input.isEmpty) {
                                                EasyLoading.showError(
                                                  'Input is null',
                                                );
                                                return;
                                              }
                                              if (!(input.startsWith(
                                                    'http',
                                                  ) ||
                                                  input.startsWith(
                                                    'https',
                                                  ))) {
                                                EasyLoading.showError(
                                                  'Invalid URL',
                                                );
                                                return;
                                              }
                                              try {
                                                EasyLoading.show(
                                                  status: 'Processing',
                                                );
                                                await controller
                                                    .addMintUrl(input);
                                                EasyLoading.showSuccess(
                                                  'Added',
                                                );

                                                Get.back<void>();
                                              } catch (e, s) {
                                                logger.e(
                                                  e.toString(),
                                                  error: e,
                                                  stackTrace: s,
                                                );
                                                final msg =
                                                    Utils.getErrorMessage(
                                                  e,
                                                );
                                                EasyLoading.showToast(
                                                  'Exception: $msg',
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          );
                        }
                        final server = element as MintBalanceClass;
                        return Builder(
                          builder: (BuildContext context) {
                            // Create a unique gradient based on the mint name
                            final mintHash = server.mint.hashCode;
                            final gradientColors = [
                              KeychatGlobal.secondaryColor.withAlpha(100),
                              Color(
                                (mintHash & 0xFFFFFF) | 0x40000000,
                              ), // Derived color with opacity
                            ];

                            return GestureDetector(
                              onTap: () {
                                mintTap(server);
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: gradientColors,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Expanded(
                                        child: Icon(
                                          CupertinoIcons.bitcoin_circle,
                                          color: Color(0xfff2a900),
                                          size: 42,
                                        ),
                                      ),
                                      Text(
                                        server.mint,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall!
                                                  .color
                                                  ?.withAlpha(160),
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          RichText(
                                            text: TextSpan(
                                              text: server.balance.toString(),
                                              children: <TextSpan>[
                                                TextSpan(
                                                  text:
                                                      ' ${EcashTokenSymbol.sat.name}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                              style: TextStyle(
                                                height: 1.3,
                                                fontSize: 28,
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge!
                                                    .color,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () {
                                              mintTap(server);
                                            },
                                            icon: const Icon(
                                              CupertinoIcons.right_chevron,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transactions',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      TextButton(
                        onPressed: () {
                          Get.to(
                            () => const TransactionsPage(),
                            id: GetPlatform.isDesktop
                                ? GetXNestKey.ecash
                                : null,
                          );
                        },
                        child: const Text('More >'),
                      ),
                    ],
                  ),
                ),
                const _RecentTransactionsWidget(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleReceive() {
    Get.bottomSheet(
      ignoreSafeArea: false,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      SettingsList(
        platform: DevicePlatform.iOS,
        sections: [
          SettingsSection(
            tiles: [
              SettingsTile.navigation(
                title: const Text('Receive from Lightning Wallet'),
                onPressed: (context) async {
                  Get.back<void>();
                  final result = await Get.bottomSheet<Transaction>(
                    ignoreSafeArea: false,
                    clipBehavior: Clip.antiAlias,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                    CreateInvoicePage(),
                  );
                  if (result == null) return;
                  await Get.to(
                    () => LightningTransactionPage(transaction: result),
                    id: GetPlatform.isDesktop ? GetXNestKey.ecash : null,
                  );
                  await controller.requestPageRefresh();
                },
              ),
              SettingsTile.navigation(
                title: const Text('Receive Ecash'),
                onPressed: (context) async {
                  Get.back<void>();
                  await Get.bottomSheet(
                    ignoreSafeArea: false,
                    clipBehavior: Clip.antiAlias,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                    const ReceiveEcash(),
                  );
                  await Get.find<EcashController>().getRecentTransactions();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleSend() async {
    await Get.bottomSheet<void>(
      SettingsList(
        platform: DevicePlatform.iOS,
        sections: [
          SettingsSection(
            tiles: [
              SettingsTile.navigation(
                title: const Text('Send to Lightning Wallet'),
                onPressed: (context) async {
                  Get.back<void>();
                  await Get.bottomSheet<void>(
                    clipBehavior: Clip.antiAlias,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                    const PayInvoicePage(),
                  );
                  unawaited(
                    controller.getRecentTransactions(),
                  );
                },
              ),
              SettingsTile.navigation(
                title: const Text('Send Ecash'),
                onPressed: (context) async {
                  Get.back<void>();
                  await Get.bottomSheet(
                    clipBehavior: Clip.antiAlias,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                    const CashuSendPage(false),
                  );
                  await Get.find<EcashController>().getRecentTransactions();
                },
              ),
            ],
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );
  }

  void mintTap(MintBalanceClass server) {
    Get.to(
      () => MintServerPage(server),
      id: GetPlatform.isDesktop ? GetXNestKey.ecash : null,
    );
  }
}

class _RecentTransactionsWidget extends GetView<EcashController> {
  const _RecentTransactionsWidget();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isRecentTransactionsLoading.value &&
          controller.recentTransactions.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator()),
        );
      }

      if (controller.recentTransactions.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Wrap(
              direction: Axis.vertical,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  Icons.folder_open_outlined,
                  size: 36,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(160),
                ),
                textSmallGray(context, 'No transactions'),
              ],
            ),
          ),
        );
      }

      return Column(
        children: [
          ...controller.recentTransactions.map((Transaction transaction) {
            final isLightning = transaction.kind == TransactionKind.ln;
            return ListTile(
              key: Key(transaction.id + transaction.timestamp.toString()),
              dense: true,
              leading: CashuUtil.getTransactionIcon(transaction.io),
              title: Text(
                isLightning
                    ? CashuUtil.getLNAmount(transaction)
                    : CashuUtil.getCashuAmount(transaction),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              subtitle: Row(
                children: [
                  if (isLightning)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(50),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'Lightning',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Expanded(
                    child: textSmallGray(
                      context,
                      'Fee: ${transaction.fee} ${transaction.unit} - ${formatTime(transaction.timestamp.toInt() * 1000)}',
                    ),
                  ),
                ],
              ),
              trailing: isLightning
                  ? CashuUtil.getLNIcon(transaction.status)
                  : CashuUtil.getStatusIcon(transaction.status),
              onTap: () async {
                if (transaction.status == TransactionStatus.expired) {
                  EasyLoading.showToast('It is expired');
                  return;
                }
                if (transaction.status == TransactionStatus.failed) {
                  EasyLoading.showToast('It is failed');
                  return;
                }

                if (isLightning) {
                  await Get.to(
                    () => LightningTransactionPage(transaction: transaction),
                    id: GetPlatform.isDesktop ? GetXNestKey.ecash : null,
                  );
                } else {
                  await Get.to(
                    () => CashuTransactionPage(transaction: transaction),
                    id: GetPlatform.isDesktop ? GetXNestKey.ecash : null,
                  );
                }

                await controller.checkAndUpdateRecentTransaction(
                  transaction,
                );
              },
            );
          }),
        ],
      );
    });
  }
}

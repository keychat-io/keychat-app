import 'dart:async';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat/page/components.dart';
import 'package:keychat/service/qrscan.service.dart';
import 'package:keychat_ecash/Bills/cashu_transaction.dart';
import 'package:keychat_ecash/Bills/lightning_transaction.dart';
import 'package:keychat_ecash/Bills/transactions_page.dart';
import 'package:keychat_ecash/EcashSetting/EcashSetting_bindings.dart';
import 'package:keychat_ecash/EcashSetting/MintServerPage.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:settings_ui/settings_ui.dart';

class CashuPage extends GetView<EcashController> {
  const CashuPage({super.key, this.isEmbedded = false});

  final bool isEmbedded;

  Widget bottomBarWidget(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16, top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 32,
          children: [
            SizedBox(
              width: 120,
              child: FilledButton.icon(
                icon: const Icon(CupertinoIcons.arrow_up_right),
                onPressed: _handleSend,
                label: const Text('Pay'),
              ),
            ),
            IconButton(
              color: Theme.of(context).colorScheme.primary,
              onPressed: () {
                QrScanService.instance.handleQRScan(autoProcess: true);
              },
              icon: const Icon(CupertinoIcons.qrcode_viewfinder, size: 24),
            ),
            SizedBox(
              width: 120,
              child: FilledButton.icon(
                icon: const Icon(CupertinoIcons.arrow_down_left),
                onPressed: _handleReceive,
                label: const Text('Receive'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isEmbedded
          ? null
          : AppBar(
              centerTitle: true,
              title: const Text('Cashu Wallet'),
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
      body: DesktopContainer(
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
                                    text: controller.totalSats.value.toString(),
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
                    if (isEmbedded)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                                id: GetPlatform.isDesktop
                                    ? GetXNestKey.ecash
                                    : null,
                              );
                            },
                            icon: const Icon(CupertinoIcons.settings),
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
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      CupertinoIcons.add_circled,
                                      size: 48,
                                    ),
                                    onPressed: () {
                                      _showAddConnectionDialog(context);
                                    },
                                  ),
                                  Text(
                                    'Add Mint',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                          id: GetPlatform.isDesktop ? GetXNestKey.ecash : null,
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
    );
  }

  Future<void> _saveMint(String input) async {
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
        status: 'Processing...',
      );
      await controller.addMintUrl(input);
      EasyLoading.showSuccess(
        'Added',
      );
    } catch (e, s) {
      logger.e(
        e.toString(),
        error: e,
        stackTrace: s,
      );
      final msg = Utils.getErrorMessage(
        e,
      );
      await EasyLoading.showToast(
        'Exception: $msg',
      );
    }
  }

  Future<void> _showAddConnectionDialog(BuildContext context) async {
    await Get.bottomSheet(
      CupertinoActionSheet(
        title: const Text('Add Mint Url'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Get.back();
              final scanned = await QrScanService.instance.handleQRScan();
              if (scanned != null && scanned.isNotEmpty) {
                await _saveMint(scanned);
              }
            },
            child: const Text('Scan QR Code'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Get.back();
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (data?.text != null && data!.text!.isNotEmpty) {
                await _saveMint(data.text!);
              } else {
                EasyLoading.showError('Clipboard is empty');
              }
            },
            child: const Text('Paste from Clipboard'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: Get.back,
          child: const Text('Cancel'),
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
                  EcashUtils.proccessMakeLnInvoice();
                },
              ),
              SettingsTile.navigation(
                title: const Text('Receive Ecash from Clipboard'),
                onPressed: (context) async {
                  Get.back<void>();
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null && data!.text!.isNotEmpty) {
                    await EcashUtils.handleReceiveToken(token: data.text!);
                  } else {
                    EasyLoading.showError('Clipboard is empty');
                  }
                },
              ),
              SettingsTile.navigation(
                title: const Text('Receive Ecash from QR Code'),
                onPressed: (context) async {
                  Get.back<void>();
                  final scanned = await QrScanService.instance.handleQRScan();
                  if (scanned != null && scanned.isNotEmpty) {
                    await EcashUtils.handleReceiveToken(token: scanned);
                  }
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
                  await Get.find<EcashController>().payToLightning(
                    null,
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
                    const CashuSendPage(isRoom: false),
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
              leading: EcashUtils.getTransactionIcon(transaction.io),
              title: Text(
                '${EcashUtils.getSymbolFromDirection(transaction.io)} ${transaction.amount}',
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
                  ? EcashUtils.getLNIcon(transaction.status)
                  : EcashUtils.getStatusIcon(transaction.status),
              onTap: () async {
                if (isLightning) {
                  await Get.to(
                    () => LightningTransactionPage(transaction: transaction),
                    id: GetPlatform.isDesktop ? GetXNestKey.ecash : null,
                  );
                  return;
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

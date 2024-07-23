// ignore_for_file: depend_on_referenced_packages

import 'package:app/app.dart';
import 'package:app/page/components.dart';
import 'package:app/page/theme.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:keychat_ecash/Bills/cashu_transaction.dart';
import 'package:keychat_ecash/Bills/ecash_bill_controller.dart';
import 'package:keychat_ecash/Bills/lightning_bill_controller.dart';
import 'package:keychat_ecash/Bills/lightning_transaction.dart';
import 'package:keychat_ecash/EcashSetting/EcashSetting_bindings.dart';
import 'package:keychat_ecash/receive_ecash_page.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_ecash/CreateInvoice/CreateInvoice_page.dart';
import 'package:keychat_ecash/PayInvoice/PayInvoice_page.dart';
import 'package:app/page/routes.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:settings_ui/settings_ui.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rustCashu;

import 'package:flutter_easyloading/flutter_easyloading.dart';

const int billLimit = 3;

class CashuPage extends GetView<EcashController> {
  const CashuPage({super.key});
  @override
  Widget build(context) {
    EcashBillController ecashBillController = Get.put(EcashBillController());
    LightningBillController lightningBillController =
        Get.put(LightningBillController());
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            "Bitcoin Ecash(Cashu)",
          ),
          actions: [
            IconButton(
                onPressed: () {
                  Get.to(() => const EcashSettingPage(),
                      binding: EcashSettingBindings());
                },
                icon: const Icon(CupertinoIcons.settings))
          ],
        ),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.miniCenterDocked,
        floatingActionButton: bottomBarWidget(context,
            controller: controller,
            ecashBillController: ecashBillController,
            lightningBillController: lightningBillController),
        body: SmartRefresher(
          enablePullDown: true,
          header: const WaterDropHeader(),
          onRefresh: () async {
            await rustCashu.checkPending();
            await controller.getBalance();
            await ecashBillController.getTransactions();
            await lightningBillController.getTransactions();
            controller.refreshController.refreshCompleted();
          },
          controller: controller.refreshController,
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
                          Obx(() => RichText(
                                  text: TextSpan(
                                text: controller.totalSats.value.toString(),
                                children: <TextSpan>[
                                  TextSpan(
                                    text: ' ${EcashTokenSymbol.sat.name}',
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                                style: TextStyle(
                                    height: 1.3,
                                    fontSize: 48,
                                    color: Theme.of(context)
                                        .textTheme
                                        .titleLarge!
                                        .color,
                                    fontWeight: FontWeight.bold),
                              )))
                        ],
                      ),
                    ],
                  )),
              Obx(() => Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: CarouselSlider(
                    options: CarouselOptions(
                        height: 150.0,
                        initialPage: 0,
                        disableCenter: true,
                        viewportFraction: 0.6,
                        padEnds: false,
                        enlargeCenterPage: true,
                        enableInfiniteScroll: false),
                    items: [
                      ...controller.mintBalances,
                      '+',
                    ].map((element) {
                      if (element == "+") {
                        return Builder(
                          builder: (BuildContext context) {
                            return Container(
                                width: MediaQuery.of(context).size.width / 2,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 5.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.1),
                                ),
                                child: IconButton(
                                    icon: const Icon(
                                      CupertinoIcons.add_circled,
                                      size: 48,
                                    ),
                                    onPressed: () {
                                      var mintController =
                                          TextEditingController();
                                      Get.dialog(CupertinoAlertDialog(
                                        title: const Text('Add Mint'),
                                        content: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10),
                                            child: TextField(
                                              decoration: const InputDecoration(
                                                hintText: 'Mint URL',
                                                border: OutlineInputBorder(),
                                              ),
                                              controller: mintController,
                                            )),
                                        actions: [
                                          CupertinoDialogAction(
                                            child: const Text('Cancel'),
                                            onPressed: () async {
                                              Get.back();
                                            },
                                          ),
                                          CupertinoDialogAction(
                                            isDefaultAction: true,
                                            child: const Text('Add'),
                                            onPressed: () async {
                                              String input =
                                                  mintController.text.trim();
                                              if (input.isEmpty) {
                                                EasyLoading.showError(
                                                    'Input is null');
                                                return;
                                              }
                                              if (!(input.startsWith('http') ||
                                                  input.startsWith('https'))) {
                                                EasyLoading.showError(
                                                    'Invalid URL');
                                                return;
                                              }
                                              try {
                                                EasyLoading.show(
                                                    status: 'Processing');
                                                await controller
                                                    .addMintUrl(input);
                                                EasyLoading.showSuccess(
                                                    'Added');

                                                Get.back();
                                              } catch (e, s) {
                                                logger.e(e.toString(),
                                                    error: e, stackTrace: s);
                                                EasyLoading.showError(
                                                    e.toString());
                                              }
                                            },
                                          )
                                        ],
                                      ));
                                    }));
                          },
                        );
                      }
                      var server = (element as MintBalanceClass);
                      return Builder(
                        builder: (BuildContext context) {
                          return GestureDetector(
                              onLongPress: () {
                                // delete item
                                Get.bottomSheet(SettingsList(
                                  platform: DevicePlatform.iOS,
                                  sections: [
                                    SettingsSection(
                                      title: Text(server.mint),
                                      tiles: [
                                        SettingsTile(
                                          title: const Text('Delete Mint',
                                              style:
                                                  TextStyle(color: Colors.red)),
                                          onPressed: (context) async {
                                            try {
                                              EcashController ec =
                                                  Get.find<EcashController>();
                                              if (ec.mintBalances.length == 1) {
                                                EasyLoading.showError(
                                                    'Can\'t delete the last mint');
                                                return;
                                              }
                                              EasyLoading.show(
                                                  status: 'Proccessing');

                                              int balance = ec.getBalanceByMint(
                                                  server.mint);
                                              if (balance > 0) {
                                                EasyLoading.showError(
                                                    'Please withdraw first');
                                                return;
                                              }
                                              if (balance == 0) {
                                                await rustCashu.removeMint(
                                                    url: server.mint);
                                              }
                                              await ec.getBalance();
                                              EasyLoading.showToast(
                                                  'Successfully');
                                            } catch (e, s) {
                                              EasyLoading.dismiss();
                                              String msg =
                                                  Utils.getErrorMessage(e);

                                              logger.e(e.toString(),
                                                  error: e, stackTrace: s);
                                              EasyLoading.showError(msg);
                                            }
                                          },
                                        )
                                      ],
                                    )
                                  ],
                                ));
                              },
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 5.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.1),
                                ),
                                child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Expanded(
                                            child: Wrap(
                                          runAlignment: WrapAlignment.start,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Icon(CupertinoIcons.bitcoin_circle,
                                                color: Color(0xfff2a900),
                                                size: 42),
                                            // SizedBox(
                                            //   width: 5,
                                            // ),
                                            // Text(server.token.toUpperCase(),
                                            //     style: Theme.of(context)
                                            //         .textTheme
                                            //         .titleMedium)
                                          ],
                                        )),
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
                                                      ?.withOpacity(0.6)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
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
                                              fontWeight: FontWeight.bold),
                                        )),
                                      ],
                                    )),
                              ));
                        },
                      );
                    }).toList(),
                  ))),
              Padding(
                  padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Ecash Bills',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).textTheme.bodyLarge!.color),
                          onPressed: () {
                            Get.toNamed(Routes.ecashBillCashu);
                          },
                          child: const Text('More'),
                        )
                      ])),
              Obx(() => Column(
                    children: ecashBillController.transactions.isEmpty
                        ? [
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 20),
                                child: Wrap(
                                  direction: Axis.vertical,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Icon(Icons.folder_open_outlined,
                                        size: 36,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.6)),
                                    textSmallGray(context, 'No transactions')
                                  ],
                                ))
                          ]
                        : ecashBillController.transactions
                            .sublist(
                                0,
                                ecashBillController.transactions.length >
                                        billLimit
                                    ? billLimit
                                    : ecashBillController.transactions.length)
                            .map((CashuTransaction transaction) {
                            bool isSend =
                                transaction.io == TransactionDirection.out;
                            return ListTile(
                              key: Key(
                                  transaction.id + transaction.time.toString()),
                              dense: true,
                              leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Get.isDarkMode
                                      ? Colors.white10
                                      : Colors.grey,
                                  child: Icon(
                                    isSend
                                        ? CupertinoIcons.arrow_up
                                        : CupertinoIcons.arrow_down,
                                    size: 18,
                                  )),
                              title: Text(
                                  (isSend ? "-" : "+") +
                                      (transaction.amount).toString(),
                                  style: Theme.of(context).textTheme.bodyLarge),
                              subtitle: textSmallGray(
                                  Get.context!,
                                  DateTime.fromMillisecondsSinceEpoch(
                                          transaction.time.toInt())
                                      .toString()),
                              trailing:
                                  CashuUtil.getStatusIcon(transaction.status),
                              onTap: () {
                                if (transaction.status ==
                                    TransactionStatus.failed) {
                                  EasyLoading.showToast('It is failed');
                                  return;
                                }
                                Get.to(() => CashuTransactionPage(
                                    transaction: transaction));
                              },
                            );
                          }).toList(),
                  )),
              const SizedBox(height: 20),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Lightning Bills',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).textTheme.bodyLarge!.color),
                          onPressed: () {
                            Get.toNamed(Routes.ecashBillLightning);
                          },
                          child: const Text('More'),
                        )
                      ])),
              Obx(() => Column(
                    children: lightningBillController.transactions.isEmpty
                        ? [
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 20),
                                child: Wrap(
                                  direction: Axis.vertical,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Icon(Icons.content_paste_off,
                                        size: 36,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.6)),
                                    textSmallGray(context, 'No transactions')
                                  ],
                                ))
                          ]
                        : lightningBillController.transactions
                            .sublist(
                                0,
                                lightningBillController.transactions.length >
                                        billLimit
                                    ? billLimit
                                    : lightningBillController
                                        .transactions.length)
                            .map((LNTransaction transaction) {
                            bool isSend =
                                transaction.io == TransactionDirection.out;
                            return ListTile(
                              key: Key(transaction.hash +
                                  transaction.time.toString()),
                              dense: true,
                              leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Get.isDarkMode
                                      ? Colors.white10
                                      : Colors.grey,
                                  child: Icon(
                                    isSend
                                        ? CupertinoIcons.arrow_up
                                        : CupertinoIcons.arrow_down,
                                    size: 18,
                                  )),
                              title: Text(
                                  (isSend ? "-" : "+") +
                                      (transaction.amount).toString(),
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                              subtitle: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  textSmallGray(
                                    Get.context!,
                                    transaction.pr,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  textSmallGray(
                                      Get.context!,
                                      DateTime.fromMillisecondsSinceEpoch(
                                              transaction.time.toInt())
                                          .toIso8601String())
                                ],
                              ),
                              trailing: CashuUtil.getLNIcon(transaction.status),
                              onTap: () {
                                if (transaction.status ==
                                    TransactionStatus.expired) {
                                  EasyLoading.showToast('It is expired');
                                  return;
                                }

                                if (transaction.status ==
                                    TransactionStatus.failed) {
                                  EasyLoading.showToast('It is failed');
                                  return;
                                }
                                Get.to(() => LightningTransactionPage(
                                    transaction: transaction));
                              },
                            );
                          }).toList(),
                  )),
              const SizedBox(
                height: 100,
              )
            ],
          ),
        ));
  }

  Widget bottomBarWidget(BuildContext context,
      {required EcashController controller,
      required EcashBillController ecashBillController,
      required LightningBillController lightningBillController}) {
    return SizedBox(
        width: Get.width,
        height: 50,
        child: Center(
            child: Wrap(
                direction: Axis.horizontal,
                alignment: WrapAlignment.spaceAround,
                runAlignment: WrapAlignment.spaceAround,
                children: [
              GestureDetector(
                onTap: () {
                  _handleSend(ecashBillController, lightningBillController);
                },
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFCE9FFC), Color(0xFF7367F0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    width: 150.0,
                    height: 45.0,
                    child: const Text(
                      'Send',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(
                width: 30.0,
              ),
              GestureDetector(
                onTap: () {
                  _handleReceive(ecashBillController, lightningBillController);
                },
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF3C90C), Color(0xFFFA742B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    width: 150.0,
                    height: 45.0,
                    child: const Text(
                      'Receive',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ])));
  }

  Widget bottomBarWidget2(BuildContext context,
      {required EcashController controller,
      required EcashBillController ecashBillController,
      required LightningBillController lightningBillController}) {
    return Positioned(
        bottom: 0.0,
        child: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Container(
                width: Get.width - 40,
                height: 80,
                decoration: BoxDecoration(
                  color: (Get.isDarkMode
                          ? const Color(0xFF322F32)
                          : const Color(0xFFCDD0CD))
                      .withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Center(
                    child: Wrap(spacing: 40, children: [
                  InkWell(
                    onTap: () async {
                      await Get.bottomSheet(const CashuSendPage(false));
                      ecashBillController.getTransactions();
                    },
                    child: Column(
                      children: [
                        SizedBox(
                          width: 36,
                          child: CircleAvatar(
                            backgroundColor: MaterialTheme.lightScheme()
                                .primary
                                .withOpacity(0.7),
                            radius: 20,
                            child: const Icon(CupertinoIcons.arrow_up,
                                color: Colors.white),
                          ),
                        ),
                        textSmallGray(context, 'Send'),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      await showModalBottomSheetWidget(
                          context, '', const ReceiveEcash(),
                          showAppBar: false);
                      ecashBillController.getTransactions();
                    },
                    child: Column(
                      children: [
                        SizedBox(
                          width: 36,
                          child: CircleAvatar(
                            backgroundColor: MaterialTheme.lightScheme()
                                .tertiary
                                .withOpacity(0.7),
                            radius: 20,
                            child: const Icon(CupertinoIcons.arrow_down,
                                color: Colors.white),
                          ),
                        ),
                        textSmallGray(context, 'Receive'),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      await showModalBottomSheetWidget(
                          context, '', const CreateInvoicePage(),
                          showAppBar: false);
                      lightningBillController.getTransactions();
                    },
                    child: Column(
                      children: [
                        SizedBox(
                          width: 36,
                          child: CircleAvatar(
                            backgroundColor: Get.isDarkMode
                                ? Colors.white10
                                : Colors.grey.shade300,
                            radius: 20,
                            child: Icon(CupertinoIcons.arrow_down,
                                color: Get.isDarkMode
                                    ? Colors.white70
                                    : Colors.black54),
                          ),
                        ),
                        textSmallGray(context, 'Receive from LN'),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      // await Get.to(() => const PayInvoicePage(),
                      //     binding: PayInvoiceBindings(),
                      //     transition: Transition.downToUp);
                      await showModalBottomSheetWidget(
                          context, '', const PayInvoicePage(),
                          showAppBar: false);
                      lightningBillController.getTransactions();
                    },
                    child: Column(
                      children: [
                        SizedBox(
                          width: 36,
                          child: CircleAvatar(
                            backgroundColor: Get.isDarkMode
                                ? Colors.white10
                                : Colors.grey.shade300,
                            radius: 20,
                            child: Icon(CupertinoIcons.arrow_up,
                                color: Get.isDarkMode
                                    ? Colors.white70
                                    : Colors.black54),
                          ),
                        ),
                        textSmallGray(context, 'Send to LN'),
                      ],
                    ),
                  ),
                ])))));
  }

  // void selectDefaultMint() async {
  //   EcashController cashuController = Get.find<EcashController>();

  //   String? mint = await Get.bottomSheet(
  //       SettingsList(platform: DevicePlatform.iOS, sections: [
  //     SettingsSection(
  //         title: Text('Select Default Server'),
  //         tiles: cashuController.mintBalances
  //             .map((e) => SettingsTile(
  //                   title: Text(e.mint),
  //                   value: Text('${e.balance} sats'),
  //                   onPressed: (context) {
  //                     Get.back(result: e.mint);
  //                   },
  //                 ))
  //             .toList())
  //   ]));
  //   if (mint != null) {
  //     await cashuController.setDefaultMint(mint);
  //     EasyLoading.showSuccess('Updated');
  //   }
  // }
  _handleSend(EcashBillController ecashBillController,
      LightningBillController lightningBillController) {
    Get.bottomSheet(SettingsList(platform: DevicePlatform.iOS, sections: [
      SettingsSection(tiles: [
        SettingsTile.navigation(
          title: const Text('Send Ecash'),
          onPressed: (context) async {
            await Get.bottomSheet(const CashuSendPage(false));
            ecashBillController.getTransactions();
          },
        ),
        SettingsTile.navigation(
          title: const Text('Send to Lighting Network'),
          onPressed: (context) async {
            await showModalBottomSheetWidget(
                context, '', const PayInvoicePage(),
                showAppBar: false);
            lightningBillController.getTransactions();
          },
        ),
      ])
    ]));
  }

  _handleReceive(EcashBillController ecashBillController,
      LightningBillController lightningBillController) {
    Get.bottomSheet(SettingsList(platform: DevicePlatform.iOS, sections: [
      SettingsSection(tiles: [
        SettingsTile.navigation(
          title: const Text('Receive Ecash'),
          onPressed: (context) async {
            await showModalBottomSheetWidget(context, '', const ReceiveEcash(),
                showAppBar: false);
            ecashBillController.getTransactions();
          },
        ),
        SettingsTile.navigation(
          title: const Text('Receive from Lighting Network'),
          onPressed: (context) async {
            await showModalBottomSheetWidget(
                context, '', const CreateInvoicePage(),
                showAppBar: false);
            lightningBillController.getTransactions();
          },
        ),
      ])
    ]));
  }
}

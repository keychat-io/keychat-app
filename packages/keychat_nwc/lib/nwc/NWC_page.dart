import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/global.dart';
import 'package:keychat/page/components.dart';
import 'package:keychat/utils.dart' show DesktopContainer, formatTime;
import 'package:keychat_ecash/PayInvoice/PayInvoice_page.dart';
import 'package:keychat_ecash/utils.dart' show EcashUtils;
import 'package:keychat_nwc/active_nwc_connection.dart';
import 'package:keychat_nwc/nwc/nwc_controller.dart';
import 'package:keychat_nwc/nwc/nwc_setting_page.dart';
import 'package:keychat_nwc/nwc/nwc_transaction_page.dart';
import 'package:keychat_nwc/nwc/transactions_list_page.dart';

class NwcPage extends GetView<NwcController> {
  const NwcPage({super.key, this.isEmbedded = false});

  final bool isEmbedded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isEmbedded
          ? null
          : AppBar(
              title: const Text('NWC Wallet'),
              centerTitle: true,
              actions: [
                IconButton(
                  onPressed: () async {
                    await controller.refreshBalances();
                    await EasyLoading.showInfo('Balances refreshed');
                  },
                  icon: const Icon(CupertinoIcons.refresh),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomBar(context),
      body: DesktopContainer(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 20),
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
                          () => controller.isLoading.value &&
                                  controller.activeConnections.isEmpty
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
                                    text: controller.totalSats.toString(),
                                    children: const <TextSpan>[
                                      TextSpan(
                                        text: ' sats',
                                        style: TextStyle(
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
                    if (isEmbedded) _buildRefreshButton(),
                  ],
                ),
              ),
              _buildCarousel(context),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Transactions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () {
                            if (controller.activeConnections.isNotEmpty &&
                                controller.currentIndex.value <
                                    controller.activeConnections.length) {
                              final uri = controller
                                  .activeConnections[
                                      controller.currentIndex.value]
                                  .info
                                  .uri;
                              Get.to(() => TransactionsListPage(nwcUri: uri));
                            }
                          },
                          child: const Text('More'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _buildTransactionsList(context),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16, top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 32,
          children: [
            FilledButton.icon(
              onPressed: () async {
                await Get.bottomSheet<void>(
                  clipBehavior: Clip.antiAlias,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                  const PayInvoicePage(),
                );
              },
              icon: const Icon(CupertinoIcons.arrow_up_right),
              label: const Text('Pay'),
            ),
            const SizedBox(width: 20),
            FilledButton.icon(
              onPressed: EcashUtils.proccessMakeLnInvoice,
              icon: const Icon(CupertinoIcons.arrow_down_left),
              label: const Text('Receive'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarousel(BuildContext context) {
    final connections = controller.activeConnections;
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: CarouselSlider(
        options: CarouselOptions(
          height: 150,
          disableCenter: true,
          viewportFraction: 0.5,
          padEnds: false,
          enlargeCenterPage: true,
          enableInfiniteScroll: false,
          onPageChanged: (index, reason) {
            controller.updateCurrentIndex(index);
          },
        ),
        items: [
          ...connections.map((c) => _buildConnectionCard(context, c)),
          _buildAddCard(context),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(BuildContext context) {
    if (controller.activeConnections.isEmpty) return const SizedBox();

    // Handle case where add card is selected (index out of bounds for connections)
    if (controller.currentIndex.value >= controller.activeConnections.length) {
      return const Center(child: Text('Add a new connection'));
    }

    final connection =
        controller.activeConnections[controller.currentIndex.value];
    final transactions = connection.transactions
        ?.transactions; // Assuming transactions list inside response

    // Loading state - show loading indicator
    if (controller.isLoading.value) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Error state or no data
    if (transactions == null || transactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'No transactions found.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), // Scroll handled by parent
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        return ListTile(
          leading: Icon(
            tx.type == 'incoming'
                ? Icons.arrow_downward
                : Icons.arrow_upward, // detailed type check needed
            color: tx.type == 'incoming' ? Colors.green : Colors.red,
          ),
          title: Text('${tx.amountSat} sats'),
          onTap: () {
            if (tx.invoice != null) {
              Get.to(
                () => NwcTransactionPage(
                  nwcUri: controller
                      .activeConnections[controller.currentIndex.value]
                      .info
                      .uri,
                  transaction: tx,
                ),
              );
            } else {
              EasyLoading.showToast('No invoice data');
            }
          },
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              textSmallGray(
                context,
                'Fee: ${tx.feesPaid} - ${formatTime(tx.createdAt * 1000)}',
              ),
              if (tx.description != null) Text(tx.description!),
            ],
          ),
          trailing: EcashUtils.getLNIcon(
            controller.getTransactionStatus(tx),
          ),
        );
      },
    );
  }

  Widget _buildConnectionCard(
    BuildContext context,
    ActiveNwcConnection connection,
  ) {
    final mintHash = connection.info.uri.hashCode;
    final gradientColors = [
      KeychatGlobal.secondaryColor,
      Color(
        (mintHash & 0xFFFFFF) | 0x40000000,
      ), // Derived color with opacity
    ];

    // Check if this card is currently selected
    final currentIndex = controller.activeConnections.indexOf(connection);

    return Obx(() {
      final isSelected = controller.currentIndex.value == currentIndex;

      return GestureDetector(
        onTap: () {
          Get.to<void>(() => NwcSettingPage(connection: connection));
        },
        child: Stack(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? Colors.white.withOpacity(0.3)
                        : Colors.black.withOpacity(0.2),
                    blurRadius: isSelected ? 12 : 8,
                    offset: const Offset(0, 4),
                    spreadRadius: isSelected ? 1 : 0,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.wallet, color: Colors.white),
                      if (connection.info.name != null)
                        Flexible(
                          child: Text(
                            connection.info.name!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildBalanceDisplay(connection),
                        const SizedBox(height: 4),
                        _buildMaxBudgetDisplay(connection),
                      ],
                    ),
                  ),
                  Text(
                    '${connection.info.uri.substring(0, 40)}...',
                    style: const TextStyle(color: Colors.white30, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Selected indicator overlay
            if (isSelected)
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildBalanceDisplay(ActiveNwcConnection connection) {
    if (controller.isLoading.value && connection.balance == null) {
      // Loading state
      return const SizedBox(
        height: 32,
        child: CupertinoActivityIndicator(
          color: Colors.white,
          radius: 12,
        ),
      );
    }

    if (connection.balance?.balanceSats != null) {
      // Data loaded successfully
      return Text(
        '${connection.balance!.balanceSats} sats',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    // Error state or no data
    return const Text(
      '--- sats',
      style: TextStyle(
        color: Colors.white70,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildMaxBudgetDisplay(ActiveNwcConnection connection) {
    if (controller.isLoading.value && connection.balance == null) {
      // Loading state
      return const SizedBox(
        height: 12,
        width: 100,
        child: CupertinoActivityIndicator(
          color: Colors.white54,
          radius: 6,
        ),
      );
    }

    if (connection.balance?.maxAmount != null) {
      // Data loaded successfully
      return Text(
        'Max Budget: ${connection.balance!.maxAmount}',
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      );
    }

    // Error state or no data
    return const Text(
      'Max Budget: -',
      style: TextStyle(color: Colors.white54, fontSize: 12),
    );
  }

  Widget _buildRefreshButton() {
    return IconButton(
      onPressed: () async {
        await controller.refreshBalances();
      },
      icon: const Icon(CupertinoIcons.refresh),
    );
  }

  Widget _buildAddCard(BuildContext context) {
    return Builder(
      builder: (BuildContext context) {
        return Container(
          width: MediaQuery.of(context).size.width / 2,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.onSurface.withAlpha(10),
                Theme.of(context).colorScheme.onSurface.withAlpha(40),
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
                onPressed: () => _showAddConnectionDialog(context),
              ),
              Text(
                'Add Connection',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddConnectionDialog(BuildContext context) async {
    await Get.bottomSheet(
      CupertinoActionSheet(
        title: const Text('Add NWC Connection'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Get.back();
              final scanned = await controller.qrScanService.handleQRScan();
              if (scanned != null && scanned.isNotEmpty) {
                await controller.addConnection(scanned);
              }
            },
            child: const Text('Scan QR Code'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Get.back();
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (data?.text != null && data!.text!.isNotEmpty) {
                await controller.addConnection(data.text!);
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
}

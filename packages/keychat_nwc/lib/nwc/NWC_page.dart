import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/global.dart';
import 'package:keychat/page/components.dart';
import 'package:keychat/utils.dart' show DesktopContainer, Utils, formatTime;
import 'package:keychat_ecash/PayInvoice/PayInvoice_page.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_ecash/utils.dart' show EcashUtils;
import 'package:keychat_nwc/active_nwc_connection.dart';
import 'package:keychat_nwc/nwc/nwc_controller.dart';
import 'package:keychat_nwc/nwc/nwc_setting_page.dart';
import 'package:keychat_nwc/nwc/nwc_transaction_page.dart';
import 'package:keychat_nwc/nwc/transactions_list_page.dart';
import 'package:url_launcher/url_launcher.dart';

class NwcPage extends StatefulWidget {
  const NwcPage({super.key, this.isEmbedded = false});

  final bool isEmbedded;

  @override
  State<NwcPage> createState() => _NwcPageState();
}

class _NwcPageState extends State<NwcPage> {
  late NwcController controller;

  @override
  void initState() {
    super.initState();
    controller = Utils.getOrPutGetxController(create: NwcController.new);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Scaffold(
        appBar: widget.isEmbedded
            ? null
            : AppBar(
                title: const Text('NWC Wallet'),
                centerTitle: true,
                actions: [
                  if (controller.activeConnections.isNotEmpty)
                    IconButton(
                      onPressed: () async {
                        await controller.refreshBalances();
                        await EasyLoading.showInfo('Balances refreshed');
                      },
                      icon: const Icon(CupertinoIcons.refresh),
                    ),
                ],
              ),
        bottomNavigationBar: controller.activeConnections.isEmpty
            ? null
            : _buildBottomBar(context),
        body: DesktopContainer(
          child: () {
            if (controller.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }

            // Show empty state when no connections
            if (controller.activeConnections.isEmpty) {
              return _buildEmptyState(context);
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
                                          text: ' sat',
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
                      if (widget.isEmbedded) _buildRefreshButton(),
                    ],
                  ),
                ),
                _buildCarousel(context),
                const SizedBox(height: 16),
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
                                Get.to(
                                  () => TransactionsListPage(nwcUri: uri),
                                );
                              }
                            },
                            child: const Text('More'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildTransactionsList(context),
              ],
            );
          }(),
        ),
      );
    });
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
                await Get.find<EcashController>().payToLightning(null);
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
          dense: true,
          leading: Icon(
            tx.type == 'incoming'
                ? Icons.arrow_downward
                : Icons.arrow_upward, // detailed type check needed
            color: tx.type == 'incoming' ? Colors.green : Colors.red,
          ),
          title: Text('${tx.amountSat} sat'),
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

  Widget _buildEmptyState(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        children: [
          // Hero section
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.secondaryContainer,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.flash_on,
                  size: 64,
                  color: Color(0xfff2a900),
                ),
                const SizedBox(height: 16),
                Text(
                  'Nostr Wallet Connect',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Connect your Lightning wallet to make instant payments',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer
                            .withOpacity(0.8),
                        height: 1.5,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          // Providers Header
          Text(
            'Recommended Providers',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          _buildProviderItem(
            context,
            'Coinos',
            'Easy to use web wallet with instant NWC setup',
            'https://coinos.io/',
            Icons.flash_on,
            Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildProviderItem(
            context,
            'Alby Hub',
            'Self-hosted Lightning node with full control',
            'https://albyhub.com/',
            Icons.hub_outlined,
            Colors.amber,
          ),
          const SizedBox(height: 32),
          // Add Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showAddConnectionDialog(context),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add NWC Connection'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () async {
              await launchUrl(Uri.parse('https://nwc.dev/'));
            },
            icon: const Icon(Icons.info_outline, size: 18),
            label: const Text('Learn more about NWC'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProviderItem(
    BuildContext context,
    String name,
    String description,
    String url,
    IconData icon,
    Color accentColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: accentColor.withOpacity(0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            launchUrl(Uri.parse(url));
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentColor.withOpacity(0.2),
                        accentColor.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: accentColor.withOpacity(0.9),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Recommended',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                              height: 1.3,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: accentColor.withOpacity(0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

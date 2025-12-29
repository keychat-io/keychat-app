import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat_nwc/NWC/nwc_controller.dart';
import 'package:keychat_nwc/NWC/nwc_setting_page.dart';
import 'package:keychat_nwc/active_nwc_connection.dart';

class NwcPage extends GetView<NwcController> {
  const NwcPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NWC Wallet'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => controller.refreshBalances(),
            icon: const Icon(CupertinoIcons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          children: [
            _buildCarousel(context),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Transactions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 10),
            // Placeholder for transactions
            _buildTransactionsList(context),
          ],
        );
      }),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16, top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: () => controller.payInvoice(''), // TODO: Scan logic
              icon: const Icon(CupertinoIcons.arrow_up_right),
              label: const Text('Pay Project'),
            ),
            const SizedBox(width: 20),
            FilledButton.icon(
              onPressed: () => controller.receive(),
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
    return CarouselSlider(
      options: CarouselOptions(
        height: 200,
        enableInfiniteScroll: false,
        enlargeCenterPage: true,
        viewportFraction: 0.85,
        onPageChanged: (index, reason) {
          controller.updateCurrentIndex(index);
        },
      ),
      items: [
        ...connections.map((c) => _buildConnectionCard(context, c)),
        _buildAddCard(context),
      ],
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
          title: Text(tx.description ?? 'No description'),
          subtitle: Text(
            DateTime.fromMillisecondsSinceEpoch(tx.createdAt * 1000).toString(),
          ), // Verify timestamp format
          trailing: Text(
            '${tx.amount} sats',
            style: TextStyle(
              color: tx.type == 'incoming' ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectionCard(
    BuildContext context,
    ActiveNwcConnection connection,
  ) {
    return GestureDetector(
      onTap: () {
        Get.to<void>(() => NwcSettingPage(connection: connection));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.purple.shade800,
              Colors.purple.shade500,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.wallet, color: Colors.white),
                if (connection.info.name != null)
                  Text(
                    connection.info.name!,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${connection.balance?.balanceSats ?? '---'} sats",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "${connection.balance?.maxAmount ?? ''} max", // Show budget if available
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
            Text(
              '${connection.info.uri.substring(0, 20)}...',
              style: const TextStyle(color: Colors.white30, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCard(BuildContext context) {
    return GestureDetector(
      onTap: _showAddConnectionDialog,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withOpacity(0.5),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 10),
              Text(
                'Add Connection',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddConnectionDialog() {
    final textController = TextEditingController();
    Get.defaultDialog<void>(
      title: 'Add NWC Connection',
      content: Column(
        children: [
          TextField(
            controller: textController,
            decoration: const InputDecoration(
              labelText: 'NWC URI',
              hintText: 'nostr+walletconnect://...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      textConfirm: 'Add',
      textCancel: 'Cancel',
      onConfirm: () {
        if (textController.text.isNotEmpty) {
          controller.addConnection(textController.text.trim());
        }
      },
    );
  }
}

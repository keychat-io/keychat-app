import 'package:flutter/material.dart';
import 'package:keychat/service/storage.dart';
import 'package:keychat_ecash/cashu_page.dart';
import 'package:keychat_nwc/nwc/nwc_page.dart';

class WalletMainDesktop extends StatefulWidget {
  const WalletMainDesktop({super.key});

  @override
  State<WalletMainDesktop> createState() => _WalletMainDesktopState();
}

class _WalletMainDesktopState extends State<WalletMainDesktop>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const String _storageKey = 'wallet_main_desktop_tab_index';

  @override
  void initState() {
    super.initState();
    // Get last selected tab index, default to 0 (Cashu)
    final savedIndex = Storage.sp.getInt(_storageKey) ?? 0;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: savedIndex.clamp(0, 1),
    );

    // Listen to tab changes and save the selection
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        Storage.sp.setInt(_storageKey, _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Cashu Wallet'),
            Tab(text: 'NWC Wallet'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          CashuPage(isEmbedded: true),
          NwcPage(isEmbedded: true),
        ],
      ),
    );
  }
}

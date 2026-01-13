import 'package:keychat/page/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat/utils.dart' show Utils;
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:keychat_nwc/nwc/nwc_controller.dart';
import 'package:settings_ui/settings_ui.dart';

enum WalletType { cashu, nwc }

class WalletSelection {
  WalletSelection({
    required this.type,
    required this.id,
    required this.displayName,
  });

  final WalletType type;
  final String id; // mint URL or NWC URI
  final String displayName;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WalletSelection && other.type == type && other.id == id;
  }

  @override
  int get hashCode => type.hashCode ^ id.hashCode;
}

class SelectMintAndNwc extends StatefulWidget {
  const SelectMintAndNwc(
    this.initialSelection,
    this.selectCallback, {
    super.key,
  });

  final WalletSelection initialSelection;
  final void Function(WalletSelection) selectCallback;

  @override
  State<SelectMintAndNwc> createState() => _SelectMintAndNwcState();
}

class _SelectMintAndNwcState extends State<SelectMintAndNwc> {
  late final Rx<WalletSelection> selected;
  late final EcashController ecashController;
  late final NwcController nwcController;
  Worker? _nwcWorker;

  @override
  void initState() {
    super.initState();
    selected = Rx<WalletSelection>(widget.initialSelection);
    ecashController = Get.find<EcashController>();
    nwcController = Utils.getOrPutGetxController(create: NwcController.new);

    // Wait for NWC to load if initial selection is NWC
    if (widget.initialSelection.type == WalletType.nwc) {
      _setupNwcListener();
    }
  }

  void _setupNwcListener() {
    // Listen to activeConnections changes
    _nwcWorker = ever(
      nwcController.activeConnections,
      (connections) {
        if (connections.isNotEmpty && mounted) {
          // Verify the initial selection still exists
          if (widget.initialSelection.type == WalletType.nwc) {
            final exists = connections.any(
              (c) => c.info.uri == widget.initialSelection.id,
            );

            // If the initial NWC wallet exists, trigger a refresh by reassigning
            if (exists) {
              // Force trigger Obx update by creating a new instance
              selected.value = WalletSelection(
                type: widget.initialSelection.type,
                id: widget.initialSelection.id,
                displayName: widget.initialSelection.displayName,
              );
            }
          }

          // Force refresh to update the display
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _nwcWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.2,
      child: ListTile(
        title: Obx(() {
          final sel = selected.value;
          if (sel.type == WalletType.cashu) {
            final balance = ecashController.getBalanceByMint(sel.id);
            return Text('$balance ${EcashTokenSymbol.sat.name}');
          } else {
            // NWC wallet
            final nwc = nwcController;

            final connection = nwc.activeConnections.firstWhereOrNull(
              (c) => c.info.uri == sel.id,
            );

            if (connection?.balance != null) {
              final balanceMsat = connection!.balance!.balanceMsats;
              final balanceSat = (balanceMsat / 1000).floor();
              return Text('$balanceSat sat');
            }

            return const Text('Loading...');
          }
        }),
        subtitle: Obx(() {
          final sel = selected.value;
          return Text(
            sel.displayName,
            overflow: TextOverflow.ellipsis,
          );
        }),
        trailing: IconButton(
          icon: Icon(
            CupertinoIcons.arrow_right_arrow_left,
            size: 16,
            color: MaterialTheme.lightScheme().primary,
          ),
          onPressed: selectWallet,
        ),
        onTap: selectWallet,
      ),
    );
  }

  Future<void> selectWallet() async {
    final nwc = nwcController;
    final isRefreshing = false.obs;

    Future<void> handleRefresh() async {
      isRefreshing.value = true;
      try {
        await Future.wait([
          ecashController.getBalance(),
          nwc.refreshBalances(),
        ]);
      } finally {
        isRefreshing.value = false;
      }
    }

    final selection = await Get.bottomSheet<WalletSelection>(
      Container(
        decoration: BoxDecoration(
          color: Theme.of(Get.context!).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Wallet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(Get.context!).textTheme.titleLarge?.color,
                ),
              ),
            ),
            Flexible(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Obx(() {
                    // Build sections list
                    final sections = <SettingsSection>[];

                    // Add Mint section
                    if (ecashController.mintBalances.isNotEmpty) {
                      sections.add(
                        SettingsSection(
                          title: const Text(
                            'Cashu Mints',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          tiles: ecashController.mintBalances
                              .map(
                                (mint) => SettingsTile(
                                  title: Text(
                                    mint.mint,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${mint.balance} ${EcashTokenSymbol.sat.name}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      if (selected.value.type ==
                                              WalletType.cashu &&
                                          selected.value.id == mint.mint) ...[
                                        const SizedBox(width: 8),
                                        const Icon(
                                          CupertinoIcons.check_mark,
                                          color: Colors.green,
                                          size: 20,
                                        ),
                                      ],
                                    ],
                                  ),
                                  onPressed: (context) {
                                    Get.back(
                                      result: WalletSelection(
                                        type: WalletType.cashu,
                                        id: mint.mint,
                                        displayName: mint.mint,
                                      ),
                                    );
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      );
                    }

                    // Show loading if NWC is still loading
                    if (nwc.isLoading.value && nwc.activeConnections.isEmpty) {
                      sections.add(
                        SettingsSection(
                          title: const Text(
                            'Lightning Wallets (NWC)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          tiles: [
                            SettingsTile(
                              title: const Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Loading NWC wallets...'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    } else if (nwc.activeConnections.isNotEmpty) {
                      // Add NWC section
                      sections.add(
                        SettingsSection(
                          title: const Text(
                            'Lightning Wallets (NWC)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          tiles: nwc.activeConnections.map(
                            (connection) {
                              var balanceText = 'Loading...';
                              if (connection.balance != null) {
                                final balanceMsat =
                                    connection.balance!.balanceMsats;
                                final balanceSat = (balanceMsat / 1000).floor();
                                balanceText = '$balanceSat sat';
                              }

                              final displayName =
                                  connection.info.name ?? connection.info.uri;

                              return SettingsTile(
                                title: Text(
                                  displayName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      balanceText,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    if (selected.value.type == WalletType.nwc &&
                                        selected.value.id ==
                                            connection.info.uri) ...[
                                      const SizedBox(width: 8),
                                      const Icon(
                                        CupertinoIcons.check_mark,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                    ],
                                  ],
                                ),
                                onPressed: (context) {
                                  Get.back(
                                    result: WalletSelection(
                                      type: WalletType.nwc,
                                      id: connection.info.uri,
                                      displayName: displayName,
                                    ),
                                  );
                                },
                              );
                            },
                          ).toList(),
                        ),
                      );
                    }

                    // Check if we have any options
                    if (sections.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(32),
                        child: const Center(
                          child: Text('No wallet available'),
                        ),
                      );
                    }

                    sections.add(
                      SettingsSection(
                        tiles: [
                          SettingsTile(
                            title: Obx(
                              () => Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isRefreshing.value)
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else
                                    const Icon(
                                      CupertinoIcons.refresh,
                                      size: 16,
                                    ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isRefreshing.value
                                        ? 'Refreshing...'
                                        : 'Refresh Balances',
                                  ),
                                ],
                              ),
                            ),
                            onPressed: isRefreshing.value
                                ? null
                                : (context) => handleRefresh(),
                          ),
                        ],
                      ),
                    );

                    return SettingsList(
                      contentPadding: const EdgeInsets.all(4),
                      platform: DevicePlatform.iOS,
                      sections: sections,
                    );
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selection != null) {
      selected.value = selection;
      widget.selectCallback(selection);
    }
  }
}

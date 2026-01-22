import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/utils.dart';
import 'package:keychat_ecash/Bills/lightning_utils.dart.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_ecash/nwc/nwc_controller.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:ndk/ndk.dart' show TransactionResult;
import 'package:url_launcher/url_launcher.dart';

/// Unified Lightning transaction details page for Cashu Lightning and NWC payments.
///
/// This page directly accepts either [Transaction] (Cashu Lightning) or
/// [TransactionResult] (NWC) and handles them appropriately.
///
/// ## Transaction Types:
///
/// ### 1. Cashu Lightning Transactions ([Transaction])
/// Lightning payments processed through Cashu mints using melt/mint operations:
/// - **Send (Melt)**: Convert ecash to Lightning payment
/// - **Receive (Mint)**: Convert Lightning payment to ecash
/// - Checked via: [LightningUtils] and [EcashController]
///
/// ### 2. NWC Lightning Transactions ([TransactionResult])
/// Lightning payments via Nostr Wallet Connect protocol:
/// - **Send**: Direct Lightning payment through remote wallet
/// - **Receive**: Lightning invoice paid to remote wallet
/// - Checked via: [NwcController]
///
/// Both types share the same Lightning invoice format (BOLT11) but differ in:
/// - Payment processing method (mint vs remote wallet)
/// - Status checking mechanism
/// - Available actions (melt retry vs lookup)
///
/// ## Usage:
/// ```dart
/// // Cashu Lightning
/// Get.to(() => UnifiedTransactionPage(
///   cashuTransaction: cashuTx,
///   walletId: mintUrl,
/// ));
///
/// // NWC Lightning
/// Get.to(() => UnifiedTransactionPage(
///   nwcTransaction: nwcTx,
///   walletId: nwcUri,
/// ));
/// ```
class UnifiedTransactionPage extends StatefulWidget {
  const UnifiedTransactionPage({
    this.cashuTransaction,
    this.nwcTransaction,
    this.walletId,
    super.key,
  }) : assert(
          cashuTransaction != null || nwcTransaction != null,
          'Either cashuTransaction or nwcTransaction must be provided',
        );

  final Transaction? cashuTransaction;
  final TransactionResult? nwcTransaction;
  final String? walletId;

  @override
  State<UnifiedTransactionPage> createState() => _UnifiedTransactionPageState();
}

class _UnifiedTransactionPageState extends State<UnifiedTransactionPage> {
  late Transaction? cashuTx;
  late TransactionResult? nwcTx;
  Timer? _timer;
  bool _isChecking = false;
  bool _nwcIsPaid = false;
  int expiryTs = 0;

  bool get isCashu => cashuTx != null;
  bool get isNwc => nwcTx != null;

  // Common getters that work for both types
  TransactionStatus get _status {
    if (isCashu) {
      return cashuTx!.status;
    } else {
      return _getNwcStatus();
    }
  }

  TransactionStatus _getNwcStatus() {
    if (_nwcIsPaid) return TransactionStatus.success;

    final state = nwcTx!.state?.toLowerCase() ?? '';
    switch (state) {
      case 'settled':
      case 'paid':
      case 'success':
        return TransactionStatus.success;
      case 'pending':
        final expiresAt = nwcTx!.expiresAt ?? 0;
        if (expiresAt > 0 &&
            DateTime.now().millisecondsSinceEpoch > expiresAt * 1000) {
          return TransactionStatus.expired;
        }
        return TransactionStatus.pending;
      case 'failed':
        return TransactionStatus.failed;
      case 'expired':
        return TransactionStatus.expired;
      default:
        // Check expiry
        final expiresAt = nwcTx!.expiresAt ?? 0;
        if (expiresAt > 0 &&
            DateTime.now().millisecondsSinceEpoch > expiresAt * 1000) {
          return TransactionStatus.expired;
        }
        return TransactionStatus.pending;
    }
  }

  bool get isIncoming {
    if (isCashu) {
      return cashuTx!.io == TransactionDirection.incoming;
    } else {
      return nwcTx!.type == 'incoming';
    }
  }

  int get amountSats {
    if (isCashu) {
      return cashuTx!.amount.toInt();
    } else {
      return nwcTx!.amountSat;
    }
  }

  String? get invoice {
    if (isCashu) {
      return cashuTx!.token;
    } else {
      return nwcTx!.invoice;
    }
  }

  String? get invoiceWithoutPrefix {
    final inv = invoice;
    if (inv == null) return null;
    return inv.replaceAll('lightning:', '');
  }

  String? get description {
    if (isCashu) {
      return cashuTx!.metadata['memo'];
    } else {
      return nwcTx!.description;
    }
  }

  String? get preimage {
    if (isCashu) {
      return cashuTx!.metadata['preimage'];
    } else {
      return nwcTx!.preimage;
    }
  }

  int? get fee {
    if (isCashu) {
      final feeValue = cashuTx!.metadata['fee'];
      if (feeValue == null) return null;
      return int.tryParse(feeValue);
    } else {
      final feeValue = nwcTx!.feesPaid;
      return feeValue != null ? feeValue ~/ 1000 : null;
    }
  }

  @override
  void initState() {
    super.initState();
    cashuTx = widget.cashuTransaction;
    nwcTx = widget.nwcTransaction;

    _initializeTransaction();
  }

  Future<void> _initializeTransaction() async {
    // Decode invoice for both protocols if available
    final invoiceStr = invoice;
    if (invoiceStr != null) {
      try {
        final info = await rust_cashu.decodeInvoice(encodedInvoice: invoiceStr);
        if (mounted) {
          setState(() {
            expiryTs = info.expiryTs.toInt();
          });
        }
      } catch (e) {
        // Invoice decoding failed, continue without expiry info
      }
    }

    // Start checking for pending transactions
    if (_status == TransactionStatus.pending) {
      if (isCashu) {
        _startCashuChecking(cashuTx!);
      }
      // NWC checking is triggered manually via button
    }
  }

  void _startCashuChecking(Transaction tx) {
    LightningUtils.instance.pendingTaskMap[tx.id] = true;
    LightningUtils.instance.startCheckPending(tx, expiryTs, (updatedTx) {
      if (mounted) {
        setState(() {
          cashuTx = updatedTx;
        });
      }
    });
  }

  Future<void> _checkNwcStatus({bool silent = false}) async {
    if (_isChecking || !isNwc) return;

    final walletId = widget.walletId;

    if (walletId == null) {
      if (!silent) EasyLoading.showError('Wallet ID not found');
      return;
    }

    _isChecking = true;
    try {
      if (!silent) EasyLoading.show(status: 'Checking...');
      final controller = Get.find<NwcController>();
      final lookup = await controller.lookupInvoice(
        uri: walletId,
        invoice: nwcTx!.invoice,
        paymentHash: nwcTx!.paymentHash,
      );

      if (lookup != null && lookup.preimage.isNotEmpty) {
        if (mounted) {
          setState(() {
            _nwcIsPaid = true;
          });
          _timer?.cancel();
          if (!silent) EasyLoading.showSuccess('Payment Received!');
          controller.fetchTransactionsForCurrent();
        }
      } else {
        if (!silent) EasyLoading.showToast('Not paid yet');
      }
    } catch (e) {
      if (!silent) EasyLoading.showError('Check failed: $e');
    } finally {
      _isChecking = false;
      if (!silent) EasyLoading.dismiss();
    }
  }

  Future<void> _handleCashuMeltOperation() async {
    if (!isCashu) return;

    final tx = cashuTx!;
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
    });

    try {
      await EasyLoading.show(status: 'Checking...');
      final checkedTx = await rust_cashu.checkTransaction(id: tx.id);
      if (mounted) {
        setState(() {
          cashuTx = checkedTx;
        });
      }
      if (checkedTx.status == TransactionStatus.success) {
        Get.find<EcashController>().getBalance();
      }
      await EasyLoading.showSuccess('Checked');
    } catch (e) {
      final msg = Utils.getErrorMessage(e);
      await EasyLoading.dismiss();
      await Get.dialog<void>(
        CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text(msg),
          actions: [
            CupertinoDialogAction(
              onPressed: Get.back<void>,
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  void dispose() {
    if (isCashu) {
      LightningUtils.instance.stopCheckPending(cashuTx!);
    }
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width *
            (MediaQuery.of(context).size.width > 500 ? 0.4 : 1) -
        32;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(_getTitle()),
      ),
      body: DesktopContainer(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 16),
            // Status and Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 10,
              children: [
                _getStatusIcon(_status),
                RichText(
                  text: TextSpan(
                    text: amountSats.abs().toString(),
                    children: <TextSpan>[
                      TextSpan(
                        text: ' ${EcashTokenSymbol.sat.name}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          height: 1,
                          fontSize: 34,
                        ),
                  ),
                ),
              ],
            ),

            // Status message for expired transactions
            if (_status == TransactionStatus.expired)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    'This invoice has expired',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

            // QR Code
            if (invoiceWithoutPrefix != null)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(vertical: 16),
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Utils.genQRImage(
                      invoiceWithoutPrefix!,
                      padding: 16,
                    ),
                  ),
                ),
              ),

            // Description/Memo
            if (description != null && description!.isNotEmpty)
              Center(
                child: Text(
                  description!,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),

            // Expiry information
            if (_status == TransactionStatus.pending && expiryTs > 0)
              Text(
                'Expire At: ${formatTime(expiryTs)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),

            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
              child: Text(
                invoice ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            _buildActionButtons(context),

            const SizedBox(height: 16),

            // Transaction Details Section
            _buildTransactionDetails(context),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _getTitle() {
    return isIncoming ? 'Receive Lightning Payment' : 'Send Lightning Payment';
  }

  Widget _getStatusIcon(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.success:
        return const Icon(Icons.check_circle, color: Colors.green, size: 40);
      case TransactionStatus.pending:
        return const Icon(Icons.pending, color: Colors.orange, size: 40);
      case TransactionStatus.failed:
      case TransactionStatus.expired:
        return const Icon(Icons.error, color: Colors.red, size: 40);
    }
  }

  Widget _buildActionButtons(BuildContext context) {
    return Wrap(
      runAlignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      direction: Axis.vertical,
      spacing: 16,
      children: [
        // Copy Invoice Button
        if (invoiceWithoutPrefix != null)
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: invoiceWithoutPrefix!));
              EasyLoading.showToast('Copied');
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy Invoice'),
          ),

        // Check/Refresh Status Button
        if (_status != TransactionStatus.success)
          OutlinedButton.icon(
            onPressed: _isChecking
                ? null
                : () async {
                    if (isCashu) {
                      await _handleCashuMeltOperation();
                    } else if (isNwc) {
                      await _checkNwcStatus();
                    }
                  },
            icon: _isChecking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(_isChecking ? 'Checking...' : 'Check Status'),
          ),

        // Open in Wallet Button (for incoming transactions with pending status)
        if (isIncoming &&
            invoice != null &&
            _status == TransactionStatus.pending)
          OutlinedButton.icon(
            onPressed: () async {
              final url = invoiceWithoutPrefix!;
              final uri = Uri.parse(url);
              final res = await canLaunchUrl(uri);
              if (!res) {
                EasyLoading.showToast('No Lightning wallet found');
                return;
              }
              await launchUrl(uri);
            },
            icon: const Icon(Icons.open_in_new),
            label: Text(
              isNwc ? 'Pay with Lightning wallet' : 'Pay with Lightning wallet',
            ),
          ),
      ],
    );
  }

  Widget _buildTransactionDetails(BuildContext context) {
    return Column(
      children: [
        // Primary Information Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[300]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPrimaryInfo(
                  context,
                  icon: Icons.toll,
                  label: 'Fee',
                  value: '${fee ?? 0} sat',
                  color: Colors.orange,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Technical Details Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[300]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Technical Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),

                // Transaction ID / Payment Hash
                _buildHashRow(
                  context,
                  'Payment Hash',
                  _getTransactionHash(),
                ),

                // Preimage (if available)
                if (_status == TransactionStatus.success &&
                    preimage != null &&
                    preimage!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildHashRow(
                    context,
                    'Preimage',
                    preimage!,
                  ),
                ],

                // Mint URL for Cashu
                if (isCashu) ...[
                  const SizedBox(height: 16),
                  _buildHashRow(
                    context,
                    'Mint',
                    cashuTx!.mintUrl,
                  ),
                ],

                const SizedBox(height: 12),

                // Status
                _buildSecondaryInfo(
                  context,
                  'Status',
                  nwcTx?.state?.toLowerCase() ?? _getStatusText(_status),
                ),

                const SizedBox(height: 8),

                // Protocol
                _buildSecondaryInfo(
                  context,
                  'Payment Method',
                  isCashu ? 'Cashu Lightning' : 'Nostr Wallet Connect',
                ),

                const SizedBox(height: 8),

                // Timestamp
                _buildSecondaryInfo(
                  context,
                  'Time',
                  formatTime(_getTimestamp()),
                ),

                // Wallet ID
                if (widget.walletId != null) ...[
                  const SizedBox(height: 8),
                  _buildSecondaryInfo(
                    context,
                    'Wallet',
                    _formatWalletId(widget.walletId!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getTransactionHash() {
    if (isCashu) {
      // For Lightning transactions, prefer payment hash from metadata
      final paymentHash = cashuTx!.metadata['payment_hash'];
      return paymentHash ?? cashuTx!.id;
    } else {
      return nwcTx!.paymentHash;
    }
  }

  int _getTimestamp() {
    if (isCashu) {
      return cashuTx!.timestamp.toInt() * 1000;
    } else {
      return nwcTx!.createdAt * 1000;
    }
  }

  String _getStatusText(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.success:
        return 'Success';
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.failed:
        return 'Failed';
      case TransactionStatus.expired:
        return 'Expired';
    }
  }

  String _formatWalletId(String walletId) {
    if (walletId.length > 30) {
      return '${walletId.substring(0, 12)}...${walletId.substring(walletId.length - 12)}';
    }
    return walletId;
  }

  Widget _buildPrimaryInfo(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHashRow(BuildContext context, String label, String hash) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hash,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: hash));
                  EasyLoading.showToast('Copied to clipboard');
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.copy,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryInfo(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        Flexible(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

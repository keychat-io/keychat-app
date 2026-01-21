import 'dart:math' show min;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/utils.dart';
import 'package:keychat_ecash/Bills/lightning_utils.dart.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_ecash/status_enum.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:url_launcher/url_launcher.dart';

class LightningTransactionPage extends StatefulWidget {
  const LightningTransactionPage({required this.transaction, super.key});
  final Transaction transaction;

  @override
  State<LightningTransactionPage> createState() => _CashuTransactionPageState();
}

class _CashuTransactionPageState extends State<LightningTransactionPage> {
  late Transaction tx;
  int expiryTs = 0;
  bool _isChecking = false;
  rust_cashu.InvoiceInfo? _invoiceInfo;

  @override
  void initState() {
    tx = widget.transaction;
    rust_cashu.decodeInvoice(encodedInvoice: tx.token).then((value) {
      setState(() {
        expiryTs = value.expiryTs.toInt();
        _invoiceInfo = value;
      });
    });

    super.initState();

    if (tx.status != TransactionStatus.pending) return;

    LightningUtils.instance.pendingTaskMap[tx.id] = true;
    LightningUtils.instance.startCheckPending(tx, expiryTs, (ln) {
      setState(() {
        tx = ln;
      });
    });
  }

  @override
  void dispose() {
    LightningUtils.instance.stopCheckPending(tx);
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
        title: Text(
          tx.io == TransactionDirection.incoming
              ? 'Receive from Lightning'
              : 'Pay to Lightning',
        ),
      ),
      body: DesktopContainer(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 10,
              children: [
                CashuStatus.getStatusIcon(tx.status, 40),
                RichText(
                  text: TextSpan(
                    text: tx.amount.toString(),
                    children: <TextSpan>[
                      TextSpan(
                        text: ' ${EcashTokenSymbol.sat.name}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(height: 1, fontSize: 34),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 16),
              child: Center(
                child: Utils.genQRImage(
                  'lightning:${tx.token}',
                  size: min(maxWidth, 300),
                  padding: 16,
                ),
              ),
            ),
            // Memo/Description
            if (tx.metadata['memo'] != null && tx.metadata['memo']!.isNotEmpty)
              Center(
                child: Text(
                  tx.metadata['memo']!,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            if (tx.status == TransactionStatus.pending && expiryTs > 0)
              Text(
                'Expire At: ${formatTime(expiryTs * 1000)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            const SizedBox(height: 16),
            // Action Buttons
            Wrap(
              runAlignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              direction: Axis.vertical,
              spacing: 16,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: 'lightning:${tx.token}'),
                    );
                    EasyLoading.showToast('Copied');
                  },
                  style: ButtonStyle(
                    minimumSize: WidgetStateProperty.all(Size(maxWidth, 48)),
                  ),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Invoice'),
                ),
                if (tx.status != TransactionStatus.success)
                  OutlinedButton(
                    style: ButtonStyle(
                      minimumSize: WidgetStateProperty.all(
                        Size(maxWidth, 48),
                      ),
                    ),
                    onPressed: _isChecking
                        ? null
                        : () async {
                            if (_isChecking) return;
                            setState(() {
                              _isChecking = true;
                            });
                            try {
                              await EasyLoading.show(status: 'Checking...');
                              final checkedTx =
                                  await rust_cashu.checkTransaction(id: tx.id);
                              setState(() {
                                tx = checkedTx;
                              });
                              if (checkedTx.status ==
                                  TransactionStatus.success) {
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
                              setState(() {
                                _isChecking = false;
                              });
                            }
                          },
                    child: const Text('Check Status'),
                  ),
                if (tx.io == TransactionDirection.incoming &&
                    tx.status == TransactionStatus.pending)
                  OutlinedButton(
                    style: ButtonStyle(
                      minimumSize: WidgetStateProperty.all(Size(maxWidth, 48)),
                    ),
                    onPressed: () async {
                      final url = 'lightning:${tx.token}';
                      final uri = Uri.parse(url);
                      final res = await canLaunchUrl(uri);
                      if (!res) {
                        EasyLoading.showToast('No Lightning wallet found');
                        return;
                      }
                      await launchUrl(uri);
                    },
                    child: const Text('Pay with Lightning wallet'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            // Transaction Details Section
            _buildTransactionDetails(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
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
                  value: '${tx.fee.toInt()} ${tx.unit ?? 'sat'}',
                  color: Colors.orange,
                ),
                // Preimage (only show if payment is successful and outgoing)
                if (tx.status == TransactionStatus.success &&
                    tx.metadata['preimage'] != null &&
                    tx.metadata['preimage']!.isNotEmpty) ...[
                  const Divider(height: 24),
                  _buildPrimaryInfo(
                    context,
                    icon: Icons.key,
                    label: 'Preimage',
                    value: '✓ Available',
                    color: Colors.green,
                  ),
                ],
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
                _buildHashRow(context, 'Payment Hash', tx.id),
                const SizedBox(height: 16),
                // Preimage (if available)
                if (tx.status == TransactionStatus.success &&
                    tx.metadata['preimage'] != null &&
                    tx.metadata['preimage']!.isNotEmpty) ...[
                  _buildHashRow(context, 'Preimage', tx.metadata['preimage']!),
                  const SizedBox(height: 16),
                ],
                // Mint URL
                _buildHashRow(context, 'Mint', tx.mintUrl),
                const SizedBox(height: 16),
                // Timestamps
                _buildSecondaryInfo(
                  context,
                  'Created At',
                  DateTime.fromMillisecondsSinceEpoch(
                    tx.timestamp.toInt() * 1000,
                  ).toIso8601String(),
                ),
                if (_invoiceInfo != null &&
                    _invoiceInfo!.expiryTs > BigInt.zero) ...[
                  const SizedBox(height: 8),
                  _buildSecondaryInfo(
                    context,
                    'Expires At',
                    DateTime.fromMillisecondsSinceEpoch(
                      _invoiceInfo!.expiryTs.toInt(),
                    ).toIso8601String(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
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
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: hash));
                  EasyLoading.showToast('Copied');
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.copy,
                    size: 16,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
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
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.success:
        return Colors.green;
      case TransactionStatus.pending:
        return Colors.orange;
      case TransactionStatus.failed:
      case TransactionStatus.expired:
        return Colors.red;
    }
  }
}

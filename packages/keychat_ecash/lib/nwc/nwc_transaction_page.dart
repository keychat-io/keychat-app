import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/utils.dart';
import 'package:keychat_ecash/nwc/nwc_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart'
    show TransactionStatus;
import 'package:ndk/domain_layer/usecases/nwc/consts/transaction_type.dart'
    show TransactionType;
import 'package:ndk/ndk.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class NwcTransactionPage extends StatefulWidget {
  const NwcTransactionPage({
    required this.nwcUri,
    required this.transaction,
    super.key,
  });

  final String nwcUri;
  final TransactionResult transaction;

  @override
  State<NwcTransactionPage> createState() => _NwcTransactionPageState();
}

class _NwcTransactionPageState extends State<NwcTransactionPage> {
  Timer? _timer;
  bool _isPaid = false;
  bool _isChecking = false;

  TransactionStatus get _status {
    if (_isPaid) return TransactionStatus.success;
    final controller = Get.find<NwcController>();
    return controller.getTransactionStatus(widget.transaction);
  }

  @override
  void initState() {
    super.initState();
    _isPaid = _status == TransactionStatus.success;
    // if (_status == TransactionStatus.pending) {
    //   _startPolling();
    // }
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (_status != TransactionStatus.pending) {
        timer.cancel();
        if (mounted) setState(() {}); // Update UI for state change
        return;
      }
      await _checkStatus(silent: true);
    });
  }

  Future<void> _checkStatus({bool silent = false}) async {
    if (_isChecking) return;
    _isChecking = true;
    try {
      if (!silent) EasyLoading.show(status: 'Checking...');
      final controller = Get.find<NwcController>();
      final lookup = await controller.lookupInvoice(
        uri: widget.nwcUri,
        invoice: widget.transaction.invoice,
        paymentHash: widget.transaction.paymentHash,
      );
      if (lookup != null && lookup.preimage.isNotEmpty) {
        if (mounted) {
          setState(() {
            _isPaid = true;
          });
          _timer?.cancel();
          if (!silent) EasyLoading.showSuccess('Payment Received!');

          // Refresh controller
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

  @override
  void dispose() {
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
        title: Text(
          widget.transaction.type == TransactionType.incoming.name
              ? 'Receive via NWC'
              : 'Send via NWC',
        ),
      ),
      body: DesktopContainer(
        child: ListView(
          children: [
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isPaid || _status == TransactionStatus.success
                      ? Icons.check_circle
                      : (_status == TransactionStatus.expired
                          ? Icons.error
                          : Icons.pending),
                  color: _isPaid || _status == TransactionStatus.success
                      ? Colors.green
                      : (_status == TransactionStatus.expired
                          ? Colors.red
                          : Colors.orange),
                  size: 40,
                ),
                const SizedBox(width: 10),
                RichText(
                  text: TextSpan(
                    text: widget.transaction.amountSat.toString(),
                    children: const <TextSpan>[
                      TextSpan(
                        text: ' sat',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
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
            if (_status == TransactionStatus.expired)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    'Invoice Expired',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    data: 'lightning:${widget.transaction.invoice}',
                    size: maxWidth > 300 ? 300 : maxWidth,
                  ),
                ),
              ),
            ),
            if (widget.transaction.description != null &&
                widget.transaction.description!.isNotEmpty)
              Center(
                child: Text(
                  widget.transaction.description!,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            if (_status == TransactionStatus.pending &&
                widget.transaction.expiresAt != null &&
                widget.transaction.expiresAt! > 0)
              Text(
                'Expire At: ${DateTime.fromMillisecondsSinceEpoch(widget.transaction.expiresAt! * 1000)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
              child: Text(
                widget.transaction.invoice ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              runAlignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              direction: Axis.vertical,
              spacing: 16,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(
                        text: widget.transaction.invoice.toString(),
                      ),
                    );
                    EasyLoading.showToast('Copied');
                  },
                  style: ButtonStyle(
                    minimumSize: WidgetStateProperty.all(Size(maxWidth, 48)),
                  ),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Invoice'),
                ),
                if (_status == TransactionStatus.pending)
                  OutlinedButton(
                    style: ButtonStyle(
                      minimumSize: WidgetStateProperty.all(
                        Size(maxWidth, 48),
                      ),
                    ),
                    onPressed: _checkStatus,
                    child: const Text('Check Status'),
                  ),
                if (_status == TransactionStatus.pending)
                  OutlinedButton(
                    style: ButtonStyle(
                      minimumSize: WidgetStateProperty.all(Size(maxWidth, 48)),
                    ),
                    onPressed: () async {
                      final url = 'lightning:${widget.transaction.invoice}';
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      } else {
                        EasyLoading.showToast('No Lightning wallet found');
                      }
                    },
                    child: const Text('Pay with Lightning wallet'),
                  ),
                const SizedBox(height: 8),
              ],
            ),
            // Transaction Details Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Primary Information Card
                  if (widget.transaction.state != null ||
                      widget.transaction.settledAt != null ||
                      widget.transaction.feesPaid != null)
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status
                            if (widget.transaction.state != null) ...[
                              _buildPrimaryInfo(
                                context,
                                icon: Icons.info_outline,
                                label: 'Status',
                                value: widget.transaction.state!,
                                color:
                                    _getStatusColor(widget.transaction.state!),
                              ),
                              if (widget.transaction.settledAt != null ||
                                  widget.transaction.feesPaid != null)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Divider(),
                                ),
                            ],

                            // Settled Time
                            if (widget.transaction.settledAt != null) ...[
                              _buildPrimaryInfo(
                                context,
                                icon: Icons.check_circle_outline,
                                label: 'Settled At',
                                value: formatTime(
                                  widget.transaction.settledAt! * 1000,
                                ),
                                color: Colors.green,
                              ),
                              if (widget.transaction.feesPaid != null)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Divider(),
                                ),
                            ],

                            // Fees Paid
                            if (widget.transaction.feesPaid != null)
                              _buildPrimaryInfo(
                                context,
                                icon: Icons.payments_outlined,
                                label: 'Network Fee',
                                value:
                                    '${widget.transaction.feesPaid! ~/ 1000} sat',
                                color: Colors.orange,
                              ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Technical Details Card
                  Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Payment Hash
                          if (widget.transaction.paymentHash.isNotEmpty &&
                              widget.transaction.paymentHash != 'none')
                            _buildHashRow(
                              context,
                              'Payment Hash',
                              widget.transaction.paymentHash,
                            ),

                          // Preimage
                          if (widget.transaction.preimage != null &&
                              widget.transaction.preimage!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildHashRow(
                              context,
                              'Preimage',
                              widget.transaction.preimage!,
                            ),
                          ],

                          // Created At
                          const SizedBox(height: 12),
                          _buildSecondaryInfo(
                            context,
                            'Created',
                            formatTime(
                              widget.transaction.createdAt * 1000,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Primary information with icon and color
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

  // Hash display with copy button
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
            border: Border.all(
              color: Colors.grey[300]!,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hash,
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 11,
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

  // Secondary information (simple text)
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
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }

  Color _getStatusColor(String state) {
    switch (state.toLowerCase()) {
      case 'settled':
      case 'paid':
      case 'success':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
      case 'expired':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}

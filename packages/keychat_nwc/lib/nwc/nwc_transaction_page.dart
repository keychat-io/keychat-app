import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_nwc/nwc.service.dart';
import 'package:keychat_nwc/nwc/nwc_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart'
    show TransactionStatus;
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
    return NwcService.instance.getTransactionStatus(widget.transaction);
  }

  @override
  void initState() {
    super.initState();
    _isPaid = _status == TransactionStatus.success;
    if (_status == TransactionStatus.pending) {
      _startPolling();
    }
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
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
      final lookup = await NwcService.instance.lookupInvoice(
        widget.nwcUri,
        invoice: widget.transaction.invoice,
      );
      if (lookup != null && lookup.preimage.isNotEmpty) {
        if (mounted) {
          setState(() {
            _isPaid = true;
          });
          _timer?.cancel();
          if (!silent) EasyLoading.showSuccess('Payment Received!');

          // Refresh controller
          try {
            final controller = Get.find<NwcController>();
            controller.refreshBalances();
            controller.fetchTransactionsForCurrent();
          } catch (_) {}
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
        title: const Text('Receive via NWC'),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView(
          children: [
            const SizedBox(height: 20),
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
                        text: ' sats',
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
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    widget.transaction.description!,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
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
            Text(
              widget.transaction.invoice ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 30),
            Wrap(
              runAlignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              direction: Axis.vertical,
              spacing: 16,
              children: [
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
                const SizedBox(height: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

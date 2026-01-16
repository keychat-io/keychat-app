import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/page/components.dart';
import 'package:keychat/utils.dart' show formatTime;
import 'package:keychat_ecash/utils.dart' show EcashUtils;
import 'package:keychat_nwc/nwc/nwc_controller.dart';
import 'package:keychat_nwc/nwc/nwc_transaction_page.dart';
import 'package:ndk/ndk.dart';

class TransactionsListPage extends StatefulWidget {
  const TransactionsListPage({required this.nwcUri, super.key});
  final String nwcUri;

  @override
  State<TransactionsListPage> createState() => _TransactionsListPageState();
}

class _TransactionsListPageState extends State<TransactionsListPage> {
  final NwcController controller = Get.find<NwcController>();
  final List<TransactionResult> _transactions = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await controller.listTransactions(
        widget.nwcUri,
        limit: _limit,
        offset: _offset,
      );

      if (response != null && response.transactions.isNotEmpty) {
        setState(() {
          _transactions.addAll(response.transactions);
          _offset += response.transactions.length;
          if (response.transactions.length < _limit) {
            _hasMore = false;
          }
        });
      } else {
        setState(() {
          _hasMore = false;
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _transactions.clear();
      _offset = 0;
      _hasMore = true;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _transactions.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _transactions.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            final tx = _transactions[index];
            return ListTile(
              onTap: () {
                if (tx.invoice != null) {
                  Get.to(
                    () => NwcTransactionPage(
                      nwcUri: widget.nwcUri,
                      transaction: tx,
                    ),
                  );
                } else {
                  EasyLoading.showToast('No invoice data');
                }
              },
              leading: Icon(
                tx.type == 'incoming'
                    ? Icons.arrow_downward
                    : Icons.arrow_upward,
                color: tx.type == 'incoming' ? Colors.green : Colors.red,
              ),
              title: Text('${tx.amountSat} sat'),
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
        ),
      ),
    );
  }
}

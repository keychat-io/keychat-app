import 'package:get/get.dart';
import 'package:keychat_nwc/active_nwc_connection.dart';
import 'package:keychat_nwc/nwc.service.dart';
import 'package:ndk/ndk.dart';

class NwcController extends GetxController {
  final NwcService _nwcService = NwcService.instance;

  final RxList<ActiveNwcConnection> activeConnections =
      <ActiveNwcConnection>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    isLoading.value = true;
    try {
      // Ensure service is initialized (if not already done elsewhere app start)
      // await _nwcService.init();
      // Assuming init called in main app, but we can refresh local list from service
      refreshList();
      await refreshBalances();
      await fetchTransactionsForCurrent();
    } finally {
      isLoading.value = false;
    }
  }

  void refreshList() {
    activeConnections.value = _nwcService.activeConnections;
  }

  Future<void> refreshBalances() async {
    await _nwcService.refreshAllBalances();
    refreshList(); // Trigger UI update if needed
  }

  Future<void> addConnection(String uri) async {
    try {
      isLoading.value = true;
      await _nwcService.add(uri);
      refreshList();
      Get.back(); // Close dialog
      Get.snackbar('Success', 'NWC Connection added');
    } catch (e) {
      Get.snackbar('Error', 'Failed to add connection: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteConnection(String uri) async {
    try {
      isLoading.value = true;
      await _nwcService.remove(uri);
      refreshList();
      Get.back(); // Close settings page or dialog
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete connection: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> payInvoice(String invoice) async {
    // Logic to select generic or specific connection?
    // For now, perhaps just pick the first one with balance or let user choose?
    // The requirement says "bottom show pay button", implies global pay?
    // Or we can default to the connection currently in focus (if we track carousel index).
    // For simplicity, let's unimplemented or pick first for now,
    // but ideally we should prompt user if multiple exist.

    if (activeConnections.isEmpty) {
      Get.snackbar('Error', 'No NWC connection available');
      return;
    }

    // TODO: Implement pay logic (maybe show dialog to pick wallet if multiple)
    Get.snackbar('Info', 'Payment flow implementation pending');
  }

  Future<void> receive() async {
    // NWC is for spending mostly, but maybe we can show invoice to receive to a linked LNbits/etc?
    // Standard NWC `make_invoice` is optional/extension.
    // We will leave this placeholder.
    Get.snackbar('Info', 'Receive flow implementation pending');
  }

  final RxInt currentIndex = 0.obs;

  void updateCurrentIndex(int index) {
    if (index >= 0 && index < activeConnections.length) {
      currentIndex.value = index;
      fetchTransactionsForCurrent();
    }
  }

  Future<void> fetchTransactionsForCurrent() async {
    if (activeConnections.isEmpty) return;
    if (currentIndex.value >= activeConnections.length) return;

    final uri = activeConnections[currentIndex.value].info.uri;
    try {
      await listTransactions(uri, limit: 10); // Default limit
      refreshList(); // Update UI to show transactions
    } catch (e) {
      // Silent fail or log?
      print('Error fetching transactions: $e');
    }
  }

  Future<ListTransactionsResponse?> listTransactions(
    String uri, {
    int? limit,
    int? offset,
  }) async {
    try {
      return await _nwcService.listTransactions(
        uri,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to list transactions: $e');
      return null;
    }
  }

  Future<MakeInvoiceResponse?> makeInvoice(
    String uri,
    int amountSats, {
    String? description,
  }) async {
    try {
      return await _nwcService.makeInvoice(
        uri,
        amountSats: amountSats,
        description: description,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to make invoice: $e');
      return null;
    }
  }

  Future<LookupInvoiceResponse?> lookupInvoice(
    String uri, {
    String? invoice,
  }) async {
    try {
      return await _nwcService.lookupInvoice(uri, invoice: invoice);
    } catch (e) {
      Get.snackbar('Error', 'Failed to lookup invoice: $e');
      return null;
    }
  }
}

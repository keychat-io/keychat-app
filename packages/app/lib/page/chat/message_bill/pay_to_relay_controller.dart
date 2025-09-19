import 'package:app/models/nostr_event_status.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PayToRelayController extends GetxController {
  PayToRelayController(this.roomId);
  final int roomId;
  RxList<NostrEventStatus> bills = <NostrEventStatus>[].obs;
  late ScrollController scrollController;
  @override
  Future<void> onInit() async {
    scrollController = ScrollController();
    bills.value = await NostrEventStatus.getPaidEvents();
    super.onInit();
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }

  Future<void> loadMore() async {
    var lastId = 999999999;
    if (bills.isNotEmpty) {
      lastId = bills.last.id;
    }
    final newBills = await NostrEventStatus.getPaidEvents(minId: lastId);
    bills.addAll(newBills);
  }
}

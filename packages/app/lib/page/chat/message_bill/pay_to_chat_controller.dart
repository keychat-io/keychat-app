import 'package:app/models/nostr_event_status.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PayToChatController extends GetxController {
  final int roomId;
  PayToChatController(this.roomId);
  RxList<NostrEventStatus> bills = <NostrEventStatus>[].obs;
  late ScrollController scrollController;
  @override
  void onInit() async {
    scrollController = ScrollController();
    bills.value = await NostrEventStatus.getPaidEvents();
    super.onInit();
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }

  Future loadMore() async {
    int lastId = 999999999;
    if (bills.isNotEmpty) {
      lastId = bills.last.id;
    }
    var newBills = await NostrEventStatus.getPaidEvents(minId: lastId);
    bills.addAll(newBills);
  }
}

import 'package:app/models/nostr_event_status.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class PayToRelayController extends GetxController {
  final int roomId;
  PayToRelayController(this.roomId);
  RxList<NostrEventStatus> bills = <NostrEventStatus>[].obs;
  late RefreshController refreshController;
  late ScrollController scrollController;
  @override
  void onInit() async {
    refreshController = RefreshController();
    scrollController = ScrollController();
    bills.value = await NostrEventStatus.getPaidEvents();
    super.onInit();
  }

  @override
  void onClose() {
    refreshController.dispose();
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

import 'package:app/models/message_bill.dart';
import 'package:app/service/message.service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class MessageBillPageController extends GetxController {
  final int roomId;
  MessageBillPageController(this.roomId);
  RxList<MessageBill> bills = <MessageBill>[].obs;
  late RefreshController refreshController;
  late ScrollController scrollController;
  @override
  void onInit() async {
    refreshController = RefreshController();
    scrollController = ScrollController();
    bills.value = await MessageService().getBillByRoomId(roomId);
    super.onInit();
  }

  @override
  void onClose() {
    refreshController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  loadMore() async {
    int lastId = 99999999;
    if (bills.isNotEmpty) {
      lastId = bills.last.id;
    }
    var newBills =
        await MessageService().getBillByRoomId(roomId, minId: lastId);
    bills.addAll(newBills);
    // bills.refresh();
  }
}

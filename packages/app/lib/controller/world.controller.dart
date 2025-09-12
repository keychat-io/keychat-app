import 'dart:math';

import 'package:app/nostr-core/filter.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/nostr-core/request.dart';
import 'package:app/service/websocket.service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants.dart';

class WorldController extends GetxController with GetTickerProviderStateMixin {
  var count = 0.obs;
  RxInt increment() => count++;
  late TabController tabController;
  RxMap<String, List<dynamic>> feeds = <String, List<dynamic>>{
    "bitcoin": [],
    "nostr": [],
  }.obs;

  @override
  void onInit() async {
    tabController = TabController(length: feeds.length, vsync: this);
    tabController.addListener(() {
      if (tabController.indexIsChanging) {
        String? name = feeds.keys.toList()[tabController.index];
        if (name.isEmpty) return;
        if (feeds[name] == null) return;
        if (feeds[name]!.isNotEmpty) return;
        getFeed(name);
      }
    });
    // getFeed('bitcoin');
    super.onInit();
  }

  @override
  onClose() {
    tabController.dispose();
    super.onClose();
  }

  void getFeeds(List<String> list) {
    for (var element in list) {
      feeds[element] = [];
      getFeed(element);
    }
  }

  Future<String> getFeed(String tag) async {
    // id ??= generate64RandomHexChars();

    String id = '${tag}_${Random().nextInt(1000000)}';
    if (feeds[id] == null) {
      feeds[tag] = [];
    }
    int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    Request requestWithFilter = Request(id, [
      Filter(
          kinds: [EventKinds.textNote],
          until: now,
          limit: 50,
          t: [tag],
          since: now - 3600 * 24)
    ]);

    var req = requestWithFilter.serialize();
    Get.find<WebsocketService>().sendRawReq(req);
    return id;
  }

  void processEvent(NostrEventModel event) {
    String? topic = event.subscriptionId?.split('_')[0];
    if (topic == null) return;
    if (feeds[topic] == null) return;
    List list = feeds[topic]!;
    for (var ne in list) {
      if (ne.id == event.id) {
        return;
      }
    }
    feeds[topic]!.add(event);
    feeds.refresh();
  }
}

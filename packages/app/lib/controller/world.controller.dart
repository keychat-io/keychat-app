import 'dart:math';

import 'package:app/nostr-core/filter.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/nostr-core/nostr_nip4_req.dart';
import 'package:app/nostr-core/request.dart';
import 'package:app/service/websocket.service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:app/constants.dart';

class WorldController extends GetxController with GetTickerProviderStateMixin {
  RxInt count = 0.obs;
  RxInt increment() => count++;
  late TabController tabController;
  RxMap<String, List<dynamic>> feeds = <String, List<dynamic>>{
    'bitcoin': [],
    'nostr': [],
  }.obs;

  @override
  Future<void> onInit() async {
    tabController = TabController(length: feeds.length, vsync: this);
    tabController.addListener(() {
      if (tabController.indexIsChanging) {
        final name = feeds.keys.toList()[tabController.index];
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
  void onClose() {
    tabController.dispose();
    super.onClose();
  }

  void getFeeds(List<String> list) {
    for (final element in list) {
      feeds[element] = [];
      getFeed(element);
    }
  }

  Future<String> getFeed(String tag) async {
    // id ??= generate64RandomHexChars();

    final id = '${tag}_${Random().nextInt(1000000)}';
    if (feeds[id] == null) {
      feeds[tag] = [];
    }
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final requestWithFilter = Request(id, [
      Filter(
        kinds: [EventKinds.textNote],
        until: now,
        limit: 50,
        t: [tag],
        since: now - 3600 * 24,
      ),
    ]);
    final req = requestWithFilter.serialize();
    Get.find<WebsocketService>().sendReqToRelays(req);
    return id;
  }

  void processEvent(NostrEventModel event) {
    final topic = event.subscriptionId?.split('_')[0];
    if (topic == null) return;
    if (feeds[topic] == null) return;
    final list = feeds[topic]!;
    for (final ne in list) {
      if (ne.id == event.id) {
        return;
      }
    }
    feeds[topic]!.add(event);
    feeds.refresh();
  }
}

import 'package:app/models/nostr_event_status.dart';

import 'package:get/get.dart';

class NostrEventsController extends GetxController {
  RxList<NostrEventStatus> events = <NostrEventStatus>[].obs;

  @override
  void onInit() async {
    events.value = await NostrEventStatus.getLatestErrorEvents(50);
    super.onInit();
  }
}

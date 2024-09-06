import 'package:app/models/db_provider.dart';
import 'package:app/models/nostr_event_status.dart';

import 'package:get/get.dart';

class NostrEventsController extends GetxController {
  RxList<NostrEventStatus> events = <NostrEventStatus>[].obs;

  @override
  void onInit() async {
    events.value = await NostrEventStatus.getLatestErrorEvents(50);
    super.onInit();
  }

  Future deleteAll() async {
    await DBProvider.database.writeTxn(() async {
      for (var e in events) {
        await DBProvider.database.nostrEventStatus.delete(e.id);
      }
    });
    events.value = await NostrEventStatus.getLatestErrorEvents(50);
  }
}

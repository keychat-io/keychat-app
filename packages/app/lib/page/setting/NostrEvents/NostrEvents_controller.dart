import 'package:app/models/db_provider.dart';
import 'package:app/models/event_log.dart';
import 'package:app/models/message.dart';
import 'package:app/service/message.service.dart';

import 'package:get/get.dart';

class NostrEventsController extends GetxController {
  RxList<EventLog> events = <EventLog>[].obs;

  @override
  void onInit() async {
    MessageService ms = MessageService();

    var list = await DBProvider().getLatestEvents();
    for (var el in list) {
      Message? m = await ms.getMessageByEventId(el.eventId);
      el.message = m;
      events.add(el);
    }
    super.onInit();
  }
}

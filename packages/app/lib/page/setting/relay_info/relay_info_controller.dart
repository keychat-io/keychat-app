import 'package:get/get.dart';
import 'package:keychat/models/relay.dart';
import 'package:keychat/service/relay.service.dart';

class RelayInfoController extends GetxController {
  RelayInfoController(this.relay0);
  final Relay relay0;
  RxMap<String, dynamic> info = <String, dynamic>{}.obs;
  Rx<Relay> relay = Relay.empty().obs;

  @override
  Future<void> onInit() async {
    relay.value = relay0;
    final result = await RelayService.instance.refreshRelayInfo(
      relays: [relay.value],
      force: true,
    );
    final data = result[relay.value.url];
    if (data != null) {
      info.value = data;
    }
    super.onInit();
  }
}

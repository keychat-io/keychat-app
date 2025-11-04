import 'package:keychat/models/relay.dart';
import 'package:keychat/service/relay.service.dart';
import 'package:get/get.dart';

class RelayInfoController extends GetxController {
  RelayInfoController(this.relay0);
  final Relay relay0;
  RxMap<String, dynamic> info = <String, dynamic>{}.obs;
  Rx<Relay> relay = Relay.empty().obs;

  @override
  Future<void> onInit() async {
    relay.value = relay0;
    final res = await RelayService.instance.fetchRelayNostrInfo(relay.value);
    if (res != null) {
      info.value = res;
    }
    super.onInit();
    RelayService.instance.initRelayFeeInfo([relay.value]);
  }
}

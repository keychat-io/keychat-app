import 'package:app/models/relay.dart';
import 'package:app/service/relay.service.dart';
import 'package:get/get.dart';

class RelayInfoController extends GetxController {
  final Relay relay0;
  RelayInfoController(this.relay0);
  RxMap<String, dynamic> info = <String, dynamic>{}.obs;
  Rx<Relay> relay = Relay.empty().obs;

  @override
  void onInit() async {
    relay.value = relay0;
    Map<String, dynamic>? res =
        await RelayService.instance.fetchRelayNostrInfo(relay.value);
    if (res != null) {
      info.value = res;
    }
    super.onInit();
    RelayService.instance.initRelayFeeInfo([relay.value]);
  }
}

import 'package:app/models/relay.dart';
import 'package:app/service/relay.service.dart';
import 'package:get/get.dart';

class RelayInfoController extends GetxController {
  RxMap<String, dynamic> info = <String, dynamic>{}.obs;
  Rx<Relay> relay = Relay.empty().obs;

  @override
  void onInit() async {
    relay.value = Get.arguments as Relay;
    Map<String, dynamic>? res =
        await RelayService.instance.fetchRelayNostrInfo(relay.value);
    if (res != null) {
      info.value = res;
    }
    super.onInit();
    RelayService.instance.initRelayFeeInfo([relay.value]);
  }
}

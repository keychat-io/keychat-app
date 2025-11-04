import 'package:keychat/models/relay.dart';
import 'package:get/get.dart';
import 'package:keychat/page/setting/relay_info/relay_info_controller.dart';

class RelayInfoBindings implements Bindings {
  RelayInfoBindings(this.relay);
  final Relay relay;
  @override
  void dependencies() {
    Get.put(RelayInfoController(relay));
  }
}

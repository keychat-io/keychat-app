import 'package:app/models/relay.dart';
import 'package:get/get.dart';
import './relay_info_controller.dart';

class RelayInfoBindings implements Bindings {
  final Relay relay;
  RelayInfoBindings(this.relay);
  @override
  void dependencies() {
    Get.put(RelayInfoController(relay));
  }
}

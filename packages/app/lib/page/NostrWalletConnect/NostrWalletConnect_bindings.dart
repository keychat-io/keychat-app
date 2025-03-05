import 'package:get/get.dart';
import './NostrWalletConnect_controller.dart';

class NostrWalletConnectBindings implements Bindings {
  @override
  void dependencies() {
    Get.put(NostrWalletConnectController());
  }
}

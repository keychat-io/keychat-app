import 'package:get/get.dart';
import 'package:keychat_ecash/nwc/nwc_controller.dart';

class NwcBindings implements Bindings {
  @override
  void dependencies() {
    Get.put(NwcController());
  }
}

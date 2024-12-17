import 'package:get/get.dart';
import 'Browser_controller.dart';

class BrowserBindings implements Bindings {
  @override
  void dependencies() {
    Get.put(BrowserController());
  }
}

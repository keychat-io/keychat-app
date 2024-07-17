import 'package:get/get.dart';
import './relay_info_controller.dart';

class RelayInfoBindings implements Bindings {
    @override
    void dependencies() {
        Get.put(RelayInfoController());
    }
}
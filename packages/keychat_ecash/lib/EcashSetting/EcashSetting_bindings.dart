import 'package:get/get.dart';
import './EcashSetting_controller.dart';

class EcashSettingBindings implements Bindings {
    @override
    void dependencies() {
        Get.put(EcashSettingController());
    }
}
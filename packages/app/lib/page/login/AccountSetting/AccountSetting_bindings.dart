import 'package:get/get.dart';
import './AccountSetting_controller.dart';

class AccountSettingBindings implements Bindings {
    @override
    void dependencies() {
        Get.put(AccountSettingController());
    }
}
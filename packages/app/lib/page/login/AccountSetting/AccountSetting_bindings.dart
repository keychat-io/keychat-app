import 'package:app/models/identity.dart';
import 'package:get/get.dart';
import './AccountSetting_controller.dart';

class AccountSettingBindings implements Bindings {
  final Identity identity;
  AccountSettingBindings(this.identity);
  @override
  void dependencies() {
    Get.put(AccountSettingController(identity));
  }
}

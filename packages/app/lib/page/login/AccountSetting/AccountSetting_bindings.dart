import 'package:keychat/models/identity.dart';
import 'package:get/get.dart';
import 'package:keychat/page/login/AccountSetting/AccountSetting_controller.dart';

class AccountSettingBindings implements Bindings {
  AccountSettingBindings(this.identity);
  final Identity identity;
  @override
  void dependencies() {
    Get.put(AccountSettingController(identity));
  }
}

import 'package:app/app.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AccountSettingController extends GetxController {
  final Identity identity0;
  AccountSettingController(this.identity0);
  Rx<Identity> identity = Identity(name: '', secp256k1PKHex: '', npub: '').obs;
  TextEditingController usernameController = TextEditingController();
  TextEditingController confirmDeleteController = TextEditingController();
  RxBool isNpub = true.obs;

  @override
  void onInit() async {
    identity.value = identity0;
    super.onInit();
  }

  @override
  void onClose() {
    usernameController.dispose();
    confirmDeleteController.dispose();
    super.onClose();
  }
}

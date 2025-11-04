import 'package:keychat/app.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AccountSettingController extends GetxController {
  AccountSettingController(this.identity0);
  final Identity identity0;
  Rx<Identity> identity = Identity(name: '', secp256k1PKHex: '', npub: '').obs;
  TextEditingController confirmDeleteController = TextEditingController();
  RxBool isNpub = true.obs;

  @override
  Future<void> onInit() async {
    identity.value = identity0;
    super.onInit();
  }

  @override
  void onClose() {
    confirmDeleteController.dispose();
    super.onClose();
  }
}

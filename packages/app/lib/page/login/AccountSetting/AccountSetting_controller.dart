import 'package:app/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AccountSettingController extends GetxController {
  Rx<Identity> identity = Identity(name: '', secp256k1PKHex: '', npub: '').obs;
  late TextEditingController usernameController;
  late TextEditingController confirmDeleteController;
  RxBool isNpub = true.obs;
  @override
  void onInit() async {
    identity.value = Get.arguments!;
    usernameController = TextEditingController(text: identity.value.name);
    confirmDeleteController = TextEditingController();
    super.onInit();
  }

  @override
  void onClose() {
    usernameController.dispose();
    confirmDeleteController.dispose();
    super.onClose();
  }
}

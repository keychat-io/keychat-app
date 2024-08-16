import 'package:app/models/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AccountSettingController extends GetxController {
  Rx<Identity> identity = Identity(
          name: '',
          mnemonic: '',
          secp256k1PKHex: '',
          secp256k1SKHex: '',
          npub: '',
          curve25519SkHex: '',
          curve25519PkHex: '')
      .obs;
  late TextEditingController usernameController;
  RxBool isNpub = true.obs;
  @override
  void onInit() async {
    identity.value = Get.arguments!;
    usernameController = TextEditingController(text: identity.value.name);
    super.onInit();
  }

  @override
  void onClose() {
    usernameController.dispose();
    super.onClose();
  }
}

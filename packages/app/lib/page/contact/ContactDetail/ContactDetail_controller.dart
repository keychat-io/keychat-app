import 'package:app/models/contact.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class ContactDetailController extends GetxController {
  Rx<Contact> contact = Contact(pubkey: '', npubkey: '', identityId: 0).obs;
  late TextEditingController usernameController;
  @override
  void onInit() async {
    var c = Get.arguments as Contact;
    if (c.npubkey.isEmpty) {
      c.npubkey = rust_nostr.getBech32PubkeyByHex(hex: c.pubkey);
    }
    contact.value = c;
    usernameController = TextEditingController();
    usernameController.text = contact.value.petname ?? '';
    super.onInit();
  }

  @override
  void onClose() {
    super.onClose();
    usernameController.dispose();
  }
}

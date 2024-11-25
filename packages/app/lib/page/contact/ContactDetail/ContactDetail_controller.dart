import 'package:app/models/contact.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class ContactDetailController extends GetxController {
  final Contact source;
  ContactDetailController(this.source);
  Rx<Contact> contact = Contact(pubkey: '', npubkey: '', identityId: 0).obs;
  late TextEditingController usernameController;
  @override
  void onInit() async {
    if (source.npubkey.isEmpty) {
      source.npubkey = rust_nostr.getBech32PubkeyByHex(hex: source.pubkey);
    }
    contact.value = source;
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
